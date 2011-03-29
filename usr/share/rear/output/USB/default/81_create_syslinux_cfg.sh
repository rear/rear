# Create a suitable syslinux configuration based on capabilities

# Test for features in syslinux
# true if syslinux supports MENU HELP directive
FEATURE_SYSLINUX_MENU_HELP=

# Test for the syslinux version
syslinux_version=$(get_version syslinux --version)

if [ -z "$syslinux_version" ]; then
    BugError "Function get_version could not detect syslinux version."
elif version_newer "$syslinux_version" 4.0 ; then
    FEATURE_SYSLINUX_MENU_HELP="y"
fi

USB_SYSLINUX_DIR=$BUILD_DIR/netfs/boot/syslinux
USB_REAR_DIR=$BUILD_DIR/netfs/$NETFS_PREFIX

if [[ ! -d "$USB_SYSLINUX_DIR" ]]; then
    mkdir -vp "$USB_SYSLINUX_DIR" >&8 || Error "Could not create USB syslinux dir [$USB_SYSLINUX_DIR] !"
fi

### We generate a main syslinux.cfg in /boot/syslinux that consist of all
### default functionality
Log "Create boot/syslinux/syslinux.cfg"
(

    if [[ "$USE_SERIAL_CONSOLE" ]]; then
        echo "serial 0 115200" >&4
    fi

    if [[ -r "$CONFIG_DIR/templates/rear.help" ]]; then
        cp "$CONFIG_DIR/templates/rear.help" "$USB_SYSLINUX_DIR/rear.help"
        echo "F1 /boot/syslinux/rear.help" >&4
    fi

    # Use menu system, if menu.c32 is available
    if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
        cp -v "$SYSLINUX_DIR/menu.c32" "$USB_SYSLINUX_DIR/menu.c32" >&8
        echo "default menu.c32" >&4
    fi

    cat <<EOF >&4
timeout 300
#noescape 1

menu title Relax and Recover v$VERSION

### Add custom items to your configuration by creating custom.cfg
include custom.cfg

### Include generated configuration
include rear.cfg

menu separator

label -
    menu label Other actions
    menu disable

EOF

    if [[ "$FEATURE_SYSLINUX_MENU_HELP" && -r "$CONFIG_DIR/templates/rear.help" ]]; then
        cat <<EOF >&4
label help
    menu label ^Help for Relax and Recover
    text help
    More information about ReaR and the steps for recovering your system
    endtext
    menu help rear.help

EOF
    fi

    # Use chain booting for booting disk, if chain.c32 is available
    if [[ -r "$SYSLINUX_DIR/chain.c32" ]]; then
        cp -v "$SYSLINUX_DIR/chain.c32" "$USB_SYSLINUX_DIR/chain.c32" >&8

        # When booting from USB disk, local disk is likely the second disk
        if [[ "$OUTPUT" == "USB" ]]; then
            localdisk="hd1"
            localbios="0x81"
            localopts="swap"
        else
            localdisk="hd0"
            localbios="0x80"
        fi

        cat <<EOF >&4
ontimeout boot$localdisk
label boot$localdisk
    menu label Boot ^Local disk ($localdisk)
    menu default
    kernel chain.c32
    append $localdisk $localopts

label bootlocal
    menu label Boot Boot ^BIOS disk ($localbios)
    text help
    Use this when booting from local disk $localdisk does not work !
    endtext
    localboot $localbios

EOF
    else
        cat <<EOF >&4
ontimeout bootlocal
label bootlocal
    menu label Boot ^Boot BIOS disk ($localbios)
    localboot $localbios

EOF
    fi

    cat <<EOF >&4
label bootnext
    menu label Boot ^Next device
    text help
    Boot from the next device in the BIOS boot order list.
    endtext
    localboot -1

EOF

    if [[ -r "$SYSLINUX_DIR/hdt.c32" ]]; then
        cp -v "$SYSLINUX_DIR/hdt.c32" "$USB_SYSLINUX_DIR/hdt.c32" >&8
        if [[ -r "/usr/share/hwdata/pci.ids" ]]; then
            cp -v "/usr/share/hwdata/pci.ids" "$USB_SYSLINUX_DIR/pci.ids" >&8
        fi
        if [[ -r "/lib/modules/$(uname -r)/modules.alias" ]]; then
            cp -v "/lib/modules/$(uname -r)/modules.alias" "$USB_SYSLINUX_DIR/modules.alias" >&8
        fi
        cat <<EOF >&4
label hdt
    menu label Hardware ^Detection tool
    text help
    Information about your current hardware configuration
    endtext
    kernel hdt.c32

EOF
    fi

    # You need the memtest86+ package installed for this to work
    MEMTEST_BIN=$(ls -d /boot/memtest86+-* | tail -1)
    if [[ -r "$MEMTEST_BIN" ]]; then
        cp -v "$MEMTEST_BIN" "$USB_SYSLINUX_DIR/memtest" >&8
        cat <<EOF >&4
label memtest
    menu label ^Memory test
    text help
    Test your memory for problems
    endtext
    kernel memtest

EOF
    fi

#    echo -e "label -\n    menu label ^Exit menu\n    menu quit\n" >&4

    if [[ -r "$SYSLINUX_DIR/reboot.c32" ]]; then
        cp -v "$SYSLINUX_DIR/reboot.c32" "$USB_SYSLINUX_DIR/reboot.c32" >&8
        cat <<EOF >&4
label reboot
    menu label ^Reboot system
    text help
    Reboot the system now
    endtext
    kernel reboot.c32

EOF
    fi

    if [[ -r "$SYSLINUX_DIR/poweroff.com" ]]; then
        cp -v "$SYSLINUX_DIR/poweroff.com" "$USB_SYSLINUX_DIR/poweroff.com" >&8
        cat <<EOF >&4
label poweroff
    menu label ^Power off system
    text help
    Power off the system now
    endtext
    kernel poweroff.com

EOF
    fi

) 4>$USB_SYSLINUX_DIR/syslinux.cfg

if [[ ! -d "$USB_REAR_DIR" ]]; then
    mkdir -vp "$USB_REAR_DIR" >&8 || Error "Could not create USB rear dir [$USB_REAR_DIR] !"
fi

### FIXME: Make sure we also support the case where NETFS_PREFIX does not conform to hostname/timestamp
### We generate a single syslinux.cfg for the current system
Log "Create $NETFS_PREFIX/syslinux.cfg"
time=$(basename $USB_REAR_DIR)
cat <<EOF >$USB_REAR_DIR/syslinux.cfg
label $(uname -n)-$time
    menu label ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2}
    text help
ReaR rescue image using kernel $(uname -r) ${IPADDR:+on $IPADDR}
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${NETFS_URL:+NETFS_URL=$NETFS_URL}
    endtext
    kernel /$NETFS_PREFIX/kernel
    append initrd=/$NETFS_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

### Clean up older images of a given system
for system in $(ls -d $BUILD_DIR/netfs/rear/*); do
    entries=$(ls -d $system/????????.???? | wc -l)
    if (( $entries <= $RETAIN_BACKUP_NR )); then
        continue
    fi
    for entry in $(seq 1 $((entries - RETAIN_BACKUP_NR))); do
        dir=$(ls -dt $system/????????.???? | tail -1)
        Log "Remove older directory $dir"
        rm -rvf $dir >&8
    done
done

### We generate a rear.cfg based on existing rear syslinux.cfg files.
Log "Create boot/syslinux/rear.cfg"
(

    oldsystem=
    for file in $(cd $BUILD_DIR/netfs; ls -d rear/*/????????.????/syslinux.cfg); do
        dir=$(dirname $file)
        time=$(basename $dir)
        system=$(basename $(dirname $dir))

        Log "Processing $file"
        if [[ "$system" != "$oldsystem" ]]; then
            if [[ "$oldsystem" ]]; then
                # Close previous submenu
                echo "menu end" >&4
            else
                # Begin recovery header at top
                echo -e "label -\n    menu label Recovery images\n    menu disable" >&4
            fi

            # Begin submenu
            cat <<EOF >&4

menu begin $system
    menu label $system
    text help
    Recover backup of $system to this system.
    endtext

EOF
        fi

        # Include entry
        echo "    include /$file" >&4
        oldsystem=$system
    done

    if [[ "$oldsystem" ]]; then
        # Close last submenu
        cat <<EOF >&4

    menu separator

    label -
        menu label ^Back
        menu default
        text help
    Return to the main ReaR menu
        endtext
        menu exit

menu end
EOF
    fi

) 4>$USB_SYSLINUX_DIR/rear.cfg

Log "Created syslinux configuration"
