# Create a suitable syslinux configuration based on capabilities

# Test for features in syslinux
# true if syslinux supports booting from /boot/syslinux
FEATURE_SYSLINUX_BOOT_SYSLINUX=
# true if syslinux supports generic syslinux.cfg
FEATURE_SYSLINUX_GENERIC_CFG=
# true if syslinux supports MENU HELP directive
FEATURE_SYSLINUX_MENU_HELP=

# Test for the syslinux version
syslinux_version=$(get_version extlinux --version)

if [ -z "$syslinux_version" ]; then
    BugError "Function get_version could not detect syslinux version."
elif version_newer "$syslinux_version" 4.02 ; then
    FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
    FEATURE_SYSLINUX_GENERIC_CFG="y"
    FEATURE_SYSLINUX_MENU_HELP="y"
elif version_newer "$syslinux_version" 4.00 ; then
    FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
    FEATURE_SYSLINUX_MENU_HELP="y"
elif version_newer "$syslinux_version" 3.35; then
    FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
fi

if [[ "$FEATURE_SYSLINUX_BOOT_SYSLINUX" ]]; then
    USB_SYSLINUX_DIR=$BUILD_DIR/netfs/boot/syslinux
else
    USB_SYSLINUX_DIR=$BUILD_DIR/netfs
fi
USB_REAR_DIR=$BUILD_DIR/netfs/$NETFS_PREFIX

if [[ ! -d "$USB_SYSLINUX_DIR" ]]; then
    mkdir -vp "$USB_SYSLINUX_DIR" >&8 || Error "Could not create USB syslinux dir [$USB_SYSLINUX_DIR] !"
fi

### We generate a main syslinux.cfg in /boot/syslinux that consist of all
### default functionality
Log "Create boot/syslinux/syslinux.cfg"
{
    if [[ "$USE_SERIAL_CONSOLE" ]]; then
        echo "serial 0 115200" >&4
    fi

    if [[ -r "$CONFIG_DIR/templates/rear.help" ]]; then
        cp "$CONFIG_DIR/templates/rear.help" "$USB_SYSLINUX_DIR/rear.help"
        echo "F1 /boot/syslinux/rear.help" >&4
        echo "MENU TABMSG Press [Tab] to edit options or [F1] for ReaR help" >&4
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

label rear
    menu label Relax and Recover
    text help
ReaR rescue image using kernel $(uname -r) ${IPADDR:+on $IPADDR}
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${NETFS_URL:+NETFS_URL=$NETFS_URL}
    endtext
    kernel /$NETFS_PREFIX/kernel
    append initrd=/$NETFS_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE

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
#            localopts="swap"
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
    menu label Boot ^BIOS disk ($localbios)
    text help
Use this when booting from local disk $localdisk does not work !
    endtext
    localboot $localbios

EOF
    else
        cat <<EOF >&4
ontimeout bootlocal
label bootlocal
    menu label Boot ^BIOS disk ($localbios)
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
        elif [[ -r "/usr/share/pci.ids" ]]; then
            cp -v "/usr/share/pci.ids" "$USB_SYSLINUX_DIR/pci.ids" >&8
        fi
        if [[ -r "/lib/modules/$(uname -r)/modules.pcimap" ]]; then
            cp -v "/lib/modules/$(uname -r)/modules.pcimap" "$USB_SYSLINUX_DIR/modules.pcimap" >&8
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
    append -

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

} 4>$USB_SYSLINUX_DIR/syslinux.cfg

if [[ ! -d "$USB_REAR_DIR" ]]; then
    mkdir -vp "$USB_REAR_DIR" >&8 || Error "Could not create USB rear dir [$USB_REAR_DIR] !"
fi

Log "Created syslinux configuration"
