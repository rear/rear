# create mount point
if [ -n "$BACKUP_DUPLICITY_NETFS_URL" -o -n "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]; then
	mkdir -p $v "$BUILD_DIR/outputfs" >&2
	StopIfError "Could not mkdir '$BUILD_DIR/outputfs'"

	AddExitTask "rmdir $v $BUILD_DIR/outputfs >&2"

	if [[ "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]] ; then
		BACKUP_DUPLICITY_NETFS_URL="var://BACKUP_DUPLICITY_NETFS_MOUNTCMD"
	fi

	mount_url $BACKUP_DUPLICITY_NETFS_URL $BUILD_DIR/outputfs $BACKUP_DUPLICITY_NETFS_OPTIONS
	
	BACKUP_DUPLICITY_URL="file://$BUILD_DIR/outputfs"
fi
