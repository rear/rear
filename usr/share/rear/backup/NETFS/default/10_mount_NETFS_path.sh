# create mount point
mkdir -p "$BUILD_DIR/netfs"
StopIfError "Could not mkdir '$BUILD_DIR/netfs'"

# don't mount anything for tape backups
if [ "$NETFS_PROTO" == "tape" ]; then
	return 0
fi

# mount the network filesystem

# default option is rw, but it is just a dummy filler
if test -z "$NETFS_OPTIONS" ; then
	NETFS_OPTIONS="rw"
fi
# if a mount command is given, use that instead
if test "$NETFS_MOUNTCMD" ; then
	Log "Mounting with '$NETFS_MOUNTCMD $BUILD_DIR/netfs'"
	$NETFS_MOUNTCMD "$BUILD_DIR/netfs" 1>&2
	StopIfError "Your NETFS mount command '$NETFS_MOUNTCMD' failed."
else
	case "$NETFS_PROTO" in
	usb ) 	Log "Running 'mount -o $NETFS_OPTIONS $NETFS_MOUNTPATH $BUILD_DIR/netfs'"
		mount -o "$NETFS_OPTIONS" "$NETFS_MOUNTPATH" "$BUILD_DIR/netfs" 1>&2
		StopIfError "Mounting '$NETFS_SHARE' [$NETFS_PROTO] failed."
		;;
	* )
		Log "Running 'mount -t $NETFS_PROTO -o $NETFS_OPTIONS $NETFS_MOUNTPATH $BUILD_DIR/netfs'"
		mount -t $NETFS_PROTO -o "$NETFS_OPTIONS" "$NETFS_MOUNTPATH" "$BUILD_DIR/netfs" 1>&2
		StopIfError "Mounting '$NETFS_HOST:/$NETFS_SHARE' [$NETFS_PROTO] failed."
		;;
	esac
fi
AddExitTask "umount -fv '$BUILD_DIR/netfs' 1>&2"
