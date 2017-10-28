# umount mountpoint
if [ -n "$BACKUP_DUPLICITY_NETFS_URL" -o -n "$BACKUP_DUPLICITY_NETFS_UMOUNTCMD" ]; then

	if [[ "$BACKUP_DUPLICITY_NETFS_UMOUNTCMD" ]] ; then
		BACKUP_DUPLICITY_NETFS_URL="var://BACKUP_DUPLICITY_NETFS_UMOUNTCMD"
	fi

	umount_url $BACKUP_DUPLICITY_NETFS_URL $BUILD_DIR/outputfs

	rmdir $v $BUILD_DIR/outputfs >&2
	if [[ $? -eq 0 ]] ; then
		# the argument to RemoveExitTask has to be identical to the one given to AddExitTask
		RemoveExitTask "rmdir $v $BUILD_DIR/outputfs >&2"
	fi
fi
