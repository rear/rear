# copy kernel and initrd to USB dir for Relax-and-Recover
#

cp -pL $v "$KERNEL_FILE" "$BUILD_DIR/outputfs/$USB_PREFIX/kernel" >&2
StopIfError "Could not create $BUILD_DIR/outputfs/$USB_PREFIX/kernel"

cp -p $v "$TMP_DIR/initrd.cgz" "$BUILD_DIR/outputfs/$USB_PREFIX/initrd.cgz" >&2
StopIfError "Could not create $BUILD_DIR/outputfs/$USB_PREFIX/initrd.cgz"

Log "Copied kernel and initrd.cgz to $USB_PREFIX"

cat "$LOGFILE" >"$BUILD_DIR/outputfs/$USB_PREFIX/rear.log"
StopIfError "Could not copy $LOGFILE to $BUILD_DIR/outputfs/$USB_PREFIX/rear.log"
Log "Saved $LOGFILE as $USB_PREFIX/rear.log"

# FIXME: This is meaningless ATM, RESULT_FILES should be put somewhere reliable and not on a temporary mounted media.
#RESULT_FILES=( "${USB_FILES[@]}" "$USB_DIR/kernel" "$USB_DIR/initrd.cgz" )
