# umount USB mountpoint

if test "$USB_UMOUNTCMD" ; then
	Log "Running '$USB_UMOUNTCMD ${BUILD_DIR}/netfs'"
	$USB_UMOUNTCMD "${BUILD_DIR}/netfs"
else
	umount "${BUILD_DIR}/netfs"
fi || Error "Could not unmount directory ${BUILD_DIR}/netfs"
