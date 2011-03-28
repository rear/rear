# Create a suitable syslinux configuration based on capabilities

NETFS_PREFIX=rear/$(uname -n)/$(date +%Y%m%d.%H%M)
USB_SYSLINUX_DIR=$BUILD_DIR/netfs/boot/syslinux
USB_REAR_DIR=$BUILD_DIR/netfs/$NETFS_PREFIX

if [[ ! -d "$USB_SYSLINUX_DIR" ]]; then
    mkdir -vp "$USB_SYSLINUX_DIR" >&8 || Error "Could not create USB syslinux dir [$USB_SYSLINUX_DIR] !"
fi

### We generate a main syslinux.cfg in /boot/syslinux that consist of all
### default functionality
Log "Create boot/syslinux/syslinux.cfg"
(

    cat <<EOF >&4
serial 0 115200
timeout 300
#noescape 1
F1 /boot/syslinux/rear.help
include custom.cfg
menu title Relax and Recover v$VERSION

### Include generated configuration
include rear.cfg

menu separator

EOF

    # Use menu system, if menu.c32 is available
    if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
        cp -v "$SYSLINUX_DIR/menu.c32" "$USB_SYSLINUX_DIR/menu.c32" >&8
        echo "default menu.c32" >&4
    fi

    cp "$CONFIG_DIR/templates/rear.help" "$USB_SYSLINUX_DIR/rear.help"
    cat <<EOF >&4
label -
    menu label Other actions
    menu disable

label help
    menu label ^Help for Relax and Recover
    text help
    More information about ReaR and the steps for recovering your system
    endtext
    menu help rear.help

EOF

    # Use chain booting for booting disk, if chain.c32 is available
    if [[ -r "$SYSLINUX_DIR/chain.c32" ]]; then
        cp -v "$SYSLINUX_DIR/chain.c32" "$USB_SYSLINUX_DIR/chain.c32" >&8
        cat <<EOF >&4
ontimeout boothd0
label boothd0
    menu label ^Boot local disk hd0
    menu default
    kernel chain.c32
    append hd0

label bootlocal
    menu label Boot ^First BIOS disk
    text help
    Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

EOF
    else
        cat <<EOF >&4
ontimeout bootlocal
label bootlocal
    menu label Boot ^First BIOS disk
    text help
    Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

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

### We generate a single syslinux.cfg for the current system
Log "Create $NETFS_PREFIX/syslinux.cfg"
time=$(basename $USB_REAR_DIR)
cat <<EOF >$USB_REAR_DIR/syslinux.cfg
label $(uname -n)-$time
    menu label ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2}
    text help
    ReaR rescue image for $(uname -n) at ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2}
    Config BACKUP=$BACKUP and OUTPUT=$OUTPUT using kernel $(uname -r)
    endtext
    kernel /$NETFS_PREFIX/kernel
    append initrd=/$NETFS_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

### Clean up older images of a given system
for system in $(ls -d $BUILD_DIR/netfs/rear/*); do
    entries=$(ls -d $system/????????.???? | wc -l)
    Log "DEBUG: $entries vs $RETAIN_BACKUP_NR"
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
            echo -e "\nmenu begin $system\n    menu label $system\n" >&4
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
        help text
    Return to the main ReaR menu
        endtext
        menu exit

menu end
EOF
    fi

) 4>$USB_SYSLINUX_DIR/rear.cfg

Log "Created syslinux configuration"
