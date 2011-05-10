# copy kernel and initrd to USB dir for Relax & Recover
#

cp -v "$BUILD_DIR/kernel" "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX/kernel" >&8 || Error "Could not create $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/kernel"

cp -v "$BUILD_DIR/initrd.cgz" "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX/initrd.cgz" >&8 || Error "Could not create $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/initrd.cgz"

Log "Copied kernel and initrd.cgz to $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/"

# Add to RESULT_FILES for emailing it
RESULT_FILES=( "${RESULT_FILES[@]}" "${USB_FILES[@]}" "$BUILD_DIR/kernel" "$BUILD_DIR/initrd.cgz" )
