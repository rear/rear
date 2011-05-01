# Create a suitable syslinux configuration based on capabilities

# Test for features in syslinux
# true if syslinux supports booting from /boot/syslinux
FEATURE_SYSLINUX_BOOT_SYSLINUX=
# true if syslinux supports generic syslinux.cfg
FEATURE_SYSLINUX_GENERIC_CFG=
# true if syslinux supports MENU HELP directive
FEATURE_SYSLINUX_MENU_HELP=

# Test for the syslinux version
syslinux_version=$(get_version syslinux --version)

# Try extlinux instead for older syslinux releases
if [ -z "$syslinux_version" ]; then
    syslinux_version=$(get_version extlinux --version)
fi
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

# finding isolinux.bin is now done in the prep stage, not here.
# therefore ISO_ISOLINUX_BIN for sure contains the full path to isolinux.bin
cp -L "$ISO_ISOLINUX_BIN" $BUILD_DIR/isolinux.bin

### We generate a main isolinux.cfg that consist of all default functionality
Log "Create isolinux.cfg"
{
    if [[ "$USE_SERIAL_CONSOLE" ]]; then
        echo "serial 0 115200" >&4
    fi

    if [[ -r "$CONFIG_DIR/templates/rear.help" ]]; then
        cp -v "$CONFIG_DIR/templates/rear.help" "$BUILD_DIR/rear.help" >&8
        ISO_FILES=( "${ISO_FILES[@]}" rear.help )
        echo "F1 /rear.help" >&4
        echo "MENU TABMSG Press [Tab] to edit options or [F1] for ReaR help" >&4
    fi

    # Use menu system, if menu.c32 is available
    if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
        cp -v "$SYSLINUX_DIR/menu.c32" "$BUILD_DIR/menu.c32" >&8
        ISO_FILES=( "${ISO_FILES[@]}" menu.c32 )
        echo "default menu.c32" >&4
    fi

    cat <<EOF >&4
timeout 300
#noescape 1

menu title Relax and Recover v$VERSION

label rear
    menu label Relax and Recover
    text help
ReaR rescue image using kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR}
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${NETFS_URL:+NETFS_URL=$NETFS_URL}
    endtext
    kernel /kernel
    append initrd=/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE

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
        cp -v "$SYSLINUX_DIR/chain.c32" "$BUILD_DIR/chain.c32" >&8
        ISO_FILES=( "${ISO_FILES[@]}" chain.c32 )

        cat <<EOF >&4
ontimeout boothd0
label boothd0
    menu label Boot ^Local disk (hd0)
    menu default
    kernel chain.c32
    append hd0

label bootlocal
    menu label Boot ^BIOS disk (0x80)
    text help
Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

EOF
    else
        cat <<EOF >&4
ontimeout bootlocal
label bootlocal
    menu label Boot ^BIOS disk (0x80)
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
        cp -v "$SYSLINUX_DIR/hdt.c32" "$BUILD_DIR/hdt.c32" >&8
        ISO_FILES=( "${ISO_FILES[@]}" hdt.c32 )
        if [[ -r "/usr/share/hwdata/pci.ids" ]]; then
            cp -v "/usr/share/hwdata/pci.ids" "$BUILD_DIR/pci.ids" >&8
            ISO_FILES=( "${ISO_FILES[@]}" pci.ids )
        elif [[ -r "/usr/share/pci.ids" ]]; then
            cp -v "/usr/share/pci.ids" "$BUILD_DIR/pci.ids" >&8
            ISO_FILES=( "${ISO_FILES[@]}" pci.ids )
        fi
        if [[ -r "/lib/modules/$KERNEL_VERSION/modules.pcimap" ]]; then
            cp -v "/lib/modules/$KERNEL_VERSION/modules.pcimap" "$BUILD_DIR/modules.pcimap" >&8
            ISO_FILES=( "${ISO_FILES[@]}" modules.pcimap )
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
    MEMTEST_BIN="$(find /boot -name "memtest*" -type f -printf '%p %A@\n' | sort -n -k2 | tail -1 | cut -d " " -f1)"
    if [[ -r "$MEMTEST_BIN" ]]; then
        cp -v "$MEMTEST_BIN" "$BUILD_DIR/memtest" >&8
        ISO_FILES=( "${ISO_FILES[@]}" memtest )
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
        cp -v "$SYSLINUX_DIR/reboot.c32" "$BUILD_DIR/reboot.c32" >&8
        ISO_FILES=( "${ISO_FILES[@]}" reboot.c32 )
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
        cp -v "$SYSLINUX_DIR/poweroff.com" "$BUILD_DIR/poweroff.com" >&8
        ISO_FILES=( "${ISO_FILES[@]}" poweroff.com )
        cat <<EOF >&4
label poweroff
    menu label ^Power off system
    text help
Power off the system now
    endtext
    kernel poweroff.com

EOF
    fi

} 4>$BUILD_DIR/isolinux.cfg

ISO_FILES=( "${ISO_FILES[@]}" isolinux.bin isolinux.cfg )

Log "Created isolinux configuration"
