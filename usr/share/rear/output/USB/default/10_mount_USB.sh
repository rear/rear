# create mount point
mkdir -p "$BUILD_DIR/netfs" || Error "Could not mkdir '$BUILD_DIR/netfs'"

# mount the USB filesystem

# if a mount command is given, use that instead
if test "$USB_MOUNTCMD" ; then
	Log "Mounting with '$USB_MOUNTCMD $BUILD_DIR/netfs'"
	$USB_MOUNTCMD "$BUILD_DIR/netfs" 1>&2 || \
		Error "Your USB mount command '$USB_MOUNTCMD' failed."
else
	Log "Running 'mount $USB_DEVICE $BUILD_DIR/netfs'"
	mount "$USB_DEVICE" "$BUILD_DIR/netfs" 1>&2 || \
		Error "Mounting '$USB_DEVICE' '$BUILD_DIR/netfs' failed."
fi
