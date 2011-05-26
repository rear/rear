# create mount point
if [[ ! -d "$BUILD_DIR/usbfs" ]]; then
	mkdir -p "$BUILD_DIR/usbfs"
	StopIfError "Could not mkdir '$BUILD_DIR/usbfs'"
fi

# if a mount command is given, use that instead
if test "$USB_MOUNTCMD" ; then
	Log "Mounting with '$USB_MOUNTCMD $BUILD_DIR/usbfs'"
	$USB_MOUNTCMD "$BUILD_DIR/usbfs" 1>&2
	StopIfError "Your USB mount command '$USB_MOUNTCMD' failed."
else
	[[ "$USB_DEVICE" ]]
	StopIfError "USB device (\$USB_DEVICE) is not set."
	Log "Running 'mount $USB_DEVICE $BUILD_DIR/usbfs'"
	mount "$USB_DEVICE" "$BUILD_DIR/usbfs" 1>&2
	StopIfError "Mounting '$USB_DEVICE' '$BUILD_DIR/usbfs' failed."
fi

AddExitTask "umount -fv '$BUILD_DIR/usbfs' 1>&2"
