# umount NETFS mountpoint

# don't mount anything for tape backups
if [ "$NETFS_PROTO" == "tape" ]; then
	return
fi

if test "$NETFS_UMOUNTCMD" ; then
	Log "Running '$NETFS_UMOUNTCMD ${BUILD_DIR}/netfs'"
	$NETFS_UMOUNTCMD "${BUILD_DIR}/netfs"
else
	Log "Running 'umount -f ${BUILD_DIR}/netfs'"
	umount -f $v "${BUILD_DIR}/netfs" >&2
fi
StopIfError "Could not unmount directory ${BUILD_DIR}/netfs"

rmdir $v $BUILD_DIR/netfs >&2

# the argument to RemoveExitTask has to be identical to the one given to AddExitTask
RemoveExitTask "umount -f $v '$BUILD_DIR/netfs' >&2"
RemoveExitTask "rmdir $v $BUILD_DIR/netfs >&2"