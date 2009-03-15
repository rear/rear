# umount NETFS mountpoint

if test "$NETFS_UMOUNTCMD" ; then
	Log "Running '$NETFS_UMOUNTCMD ${BUILD_DIR}/netfs'"
	$NETFS_UMOUNTCMD "${BUILD_DIR}/netfs"
else
	umount "${BUILD_DIR}/netfs"
fi || Error "Could not unmount directory ${BUILD_DIR}/netfs"
