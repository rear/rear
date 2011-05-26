# copy kernel and initrd to USB dir for Relax & Recover
#

cp -v "$BUILD_DIR/kernel" "$BUILD_DIR/usbfs/$USB_PREFIX/kernel" >&8
StopIfError "Could not create $BUILD_DIR/usbfs/$USB_PREFIX/kernel"

cp -v "$BUILD_DIR/initrd.cgz" "$BUILD_DIR/usbfs/$USB_PREFIX/initrd.cgz" >&8
StopIfError "Could not create $BUILD_DIR/usbfs/$USB_PREFIX/initrd.cgz"

Log "Copied kernel and initrd.cgz to $USB_PREFIX"

cat "$LOGFILE" >"$BUILD_DIR/usbfs/$USB_PREFIX/rear.log"
StopIfError "Could not copy $LOGFILE to $BUILD_DIR/usbfs/$USB_PREFIX/rear.log"
Log "Saved $LOGFILE as $USB_PREFIX/rear.log"

# FIXME: This is meaningless ATM, RESULT_FILES should be put somewhere reliable and not on a temporary mounted media.
#RESULT_FILES=( "${USB_FILES[@]}" "$USB_DIR/kernel" "$USB_DIR/initrd.cgz" )
