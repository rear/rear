# copy kernel and initrd to USB dir for Relax-and-Recover
#

cp -pL $v "$KERNEL_FILE" "$BUILD_DIR/outputfs/$USB_PREFIX/kernel" >&2 || Error "Could not create $BUILD_DIR/outputfs/$USB_PREFIX/kernel"

cp -p $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$BUILD_DIR/outputfs/$USB_PREFIX/$REAR_INITRD_FILENAME" >&2 || Error "Could not create $BUILD_DIR/outputfs/$USB_PREFIX/$REAR_INITRD_FILENAME"

Log "Copied kernel and $REAR_INITRD_FILENAME to $USB_PREFIX"

# Copy current unfinished logfile to USB dir for debug purpose.
# Usually RUNTIME_LOGFILE=/var/log/rear/rear-$HOSTNAME.log
# The RUNTIME_LOGFILE name is set by the main script from LOGFILE in default.conf
# but later user config files are sourced in the main script where LOGFILE can be set different
# so that the user config LOGFILE basename is used as target logfile name:
logfile_basename=$( basename $LOGFILE )
cat "$RUNTIME_LOGFILE" >"$BUILD_DIR/outputfs/$USB_PREFIX/$logfile_basename" || Error "Could not copy $RUNTIME_LOGFILE to $BUILD_DIR/outputfs/$USB_PREFIX/$logfile_basename"
LogPrint "Saved $RUNTIME_LOGFILE as $USB_PREFIX/$logfile_basename"

# FIXME: This is meaningless ATM, RESULT_FILES should be put somewhere reliable and not on a temporary mounted media.
#RESULT_FILES=( "${USB_FILES[@]}" "$USB_DIR/kernel" "$USB_DIR/$REAR_INITRD_FILENAME" )
