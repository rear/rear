# umount USB mountpoint if not yet done by NETFS method

if test "$USB_UMOUNTCMD" ; then
	Log "Running '$USB_UMOUNTCMD ${BUILD_DIR}/usbfs'"
	$USB_UMOUNTCMD "${BUILD_DIR}/usbfs"
else
	Log "Running 'umount -f ${BUILD_DIR}/usbfs'"
	umount -f $v "${BUILD_DIR}/usbfs"
fi
StopIfError "Could not unmount directory ${BUILD_DIR}/usbfs"

# argument to RemoveExitTask must be identical to AddExitTask
RemoveExitTask "umount -f $v '$BUILD_DIR/usbfs' 1>&2"
