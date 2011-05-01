# Create a suitable syslinux configuration based on capabilities

# Test for features in syslinux
# true if syslinux supports booting from /boot or only from / of the USB media
FEATURE_SYSLINUX_BOOT_SYSLINUX=
# true if syslinux supports MENU HELP directive
FEATURE_SYSLINUX_MENU_HELP=

# Test for the syslinux version
syslinux_version=$(get_version extlinux --version)

if [ -z "$syslinux_version" ]; then
    BugError "Function get_version could not detect extlinux version."
elif version_newer "$syslinux_version" 4.00 ; then
    FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
    FEATURE_SYSLINUX_MENU_HELP="y"
elif version_newer "$syslinux_version" 3.35; then
    FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
fi

if [ "$FEATURE_SYSLINUX_BOOT_SYSLINUX" ]; then
    USB_SYSLINUX_PREFIX=boot
else
    USB_SYSLINUX_PREFIX=
fi

if [ ! -d "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX" ]; then
    mkdir -vp "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX" >&8 || Error "Could not create USB syslinux dir [$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX] !"
fi

echo "$VERSION_INFO" >$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/message

### We generate a main extlinux.conf in /boot that consist of all
### default functionality
# FD 4 points to the main extlinux.conf file
Log "Creating extlinux.conf"
{
	if [ "$USE_SERIAL_CONSOLE" ]; then
	        echo "serial 0 115200" >&4
	fi

	echo "display message" &>4
	echo "F1 message" &>4

	if [ -s "$CONFIG_DIR/templates/rear.help" ]; then
		cp -v "$CONFIG_DIR/templates/rear.help" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/rear.help" >&8
		echo "F2 rear.help" >&4
		echo "say F2 - Show help" >&4
		echo "MENU TABMSG Press [Tab] to edit, [F2] for help, [F1] for version info" >&4
	else
		echo "MENU TABMSG Press [Tab] to edit options and [F1] for version info" >&4
	fi

    # Use menu system, if menu.c32 is available
    if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
        cp -v "$SYSLINUX_DIR/menu.c32" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/menu.c32" >&8
        echo "default menu.c32" >&4
    fi

    cat <<EOF >&4
timeout 300
#noescape 1

menu title $PRODUCT v$VERSION

label rear
	say rear - Recover $(uname -n) BACKUP=$BACKUP OUTPUT=$OUTPUT $(date -R)
    menu label ^Recover $(uname -n)
    text help
ReaR rescue image using kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${NETFS_URL:+NETFS_URL=$NETFS_URL}
    endtext
    kernel kernel
    append initrd=initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE

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
	if [ -r "$SYSLINUX_DIR/chain.c32" ]; then
        cp -v "$SYSLINUX_DIR/chain.c32" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/chain.c32" >&8

        cat <<EOF >&4
ontimeout boothd1
label boothd0
    say boothd0 - boot first local disk
    menu label Boot First ^Local disk (hd0)
    kernel chain.c32
    append hd0
label boothd1
    say boothd1 - boot second local disk
    menu label Boot ^Second Local disk (hd1)
    menu default
    kernel chain.c32
    append hd1



label bootlocal
    menu label Boot ^BIOS disk (0x80)
    text help
Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

EOF
    else
        cat <<EOF >&4
ontimeout boot80
default boot80
label boot80
say boot80 - boot first local bios disk
    menu label Boot First ^Local BIOS disk (0x80)
    menu default
    localboot 0x80
label boot81
    say boot81 - boot second local bios disk
    menu label Boot ^Second Local BIOS disk (0x81)
    localboot 0x81


EOF
    fi

    cat <<EOF >&4
label bootnext
    say bootnext - boot from next boot device
    menu label Boot ^Next device
    text help
Boot from the next device in the BIOS boot order list.
    endtext
    localboot 0

EOF

    if [[ -r "$SYSLINUX_DIR/hdt.c32" ]]; then
        cp -v "$SYSLINUX_DIR/hdt.c32" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/hdt.c32" >&8
        if [[ -r "/usr/share/hwdata/pci.ids" ]]; then
            cp -v "/usr/share/hwdata/pci.ids" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/pci.ids" >&8
        elif [[ -r "/usr/share/pci.ids" ]]; then
            cp -v "/usr/share/pci.ids" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/pci.ids" >&8
        fi
        if [[ -r "/lib/modules/$KERNEL_VERSION/modules.pcimap" ]]; then
            cp -v "/lib/modules/$KERNEL_VERSION/modules.pcimap" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/modules.pcimap" >&8
        fi
        cat <<EOF >&4
label hdt
	say hdt - Hardware Detection Tool
    menu label Hardware ^Detection tool
    text help
Information about your current hardware configuration
    endtext
    kernel hdt.c32

EOF
    fi

    # You need the memtest86+ package installed for this to work
    MEMTEST_BIN=$(ls -d /boot/memtest86+-* 2>/dev/null | tail -1)
    if [ "$MEMTEST_BIN" != "." -a -r "$MEMTEST_BIN" ]; then
        cp -v "$MEMTEST_BIN" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/memtest" >&8
        cat <<EOF >&4
label memtest
	say memtest - Run memtest86+
    menu label ^Memory test
    text help
Test your memory for problems
    endtext
    kernel memtest
    append -

EOF
    fi

    if [[ -r "$SYSLINUX_DIR/reboot.c32" ]]; then
        cp -v "$SYSLINUX_DIR/reboot.c32" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/reboot.c32" >&8
        cat <<EOF >&4
label reboot
	say reboot - Reboot the system
    menu label ^Reboot system
    text help
Reboot the system now
    endtext
    kernel reboot.c32

EOF
    fi

    if [[ -r "$SYSLINUX_DIR/poweroff.com" ]]; then
        cp -v "$SYSLINUX_DIR/poweroff.com" "$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/poweroff.com" >&8
        cat <<EOF >&4
label poweroff
	say poweroff - Poweroff the system
    menu label ^Power off system
    text help
Power off the system now
    endtext
    kernel poweroff.com

EOF
    fi

} 4>$BUILD_DIR/usbfs/$USB_SYSLINUX_PREFIX/extlinux.conf

Log "Created extlinux configuration '/$USB_SYSLINUX_PREFIX/extlinux.conf'"
