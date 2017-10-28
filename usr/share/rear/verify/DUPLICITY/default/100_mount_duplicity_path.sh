# create mount point
if [ -n "$BACKUP_URL" -o -n "$BACKUP_MOUNTCMD" ]; then
	mkdir -p $v "$BUILD_DIR/outputfs" >&2
	StopIfError "Could not mkdir '$BUILD_DIR/outputfs'"

	AddExitTask "rmdir $v $BUILD_DIR/outputfs >&2"

	if [[ "$BACKUP_MOUNTCMD" ]] ; then
		BACKUP_URL="var://BACKUP_MOUNTCMD"
	fi

	mount_url $BACKUP_URL $BUILD_DIR/outputfs $BACKUP_OPTIONS
	
	BACKUP_DUPLICITY_URL="file://$BUILD_DIR/outputfs"
fi
