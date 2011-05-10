
set_syslinux_features

if [ "$FEATURE_SYSLINUX_BOOT_SYSLINUX" ]; then
    USB_BOOT_PREFIX=boot
else
    USB_BOOT_PREFIX=
fi

if [ ! -d "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX" ]; then
    mkdir -vp "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX" >&8 || Error "Could not create USB boot dir '$BUILD_DIR/usbfs/$USB_BOOT_PREFIX'"
fi

make_syslinux_config $BUILD_DIR/boot extlinux >BUILD_DIR/boot/extlinux.conf

Log "Created extlinux configuration"

cp -v $BUILD_DIR/boot/* "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX" 1>&8

USB_FILES=( "${USB_FILES[@]}" $BUILD_DIR/boot/* )
