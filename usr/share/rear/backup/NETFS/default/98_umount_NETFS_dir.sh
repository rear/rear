# umount NETFS mountpoint

# don't mount anything for tape backups
if [ "$NETFS_PROTO" == "tape" -o "$NETFS_PROTO" == "obdr" ]; then
	return 0
fi

if test "$NETFS_UMOUNTCMD" ; then
	Log "Running '$NETFS_UMOUNTCMD ${BUILD_DIR}/netfs'"
	$NETFS_UMOUNTCMD "${BUILD_DIR}/netfs"
else
	umount "${BUILD_DIR}/netfs"
fi || Error "Could not unmount directory ${BUILD_DIR}/netfs"

# the argument to RemoveExitTask has to be identical to the one given to AddExitTask
RemoveExitTask "umount -fv '$BUILD_DIR/netfs' 1>&2"
