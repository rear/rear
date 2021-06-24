# check the backup archive on remote rsync server

case $RSYNC_PROTO in

	(ssh)
		ssh ${RSYNC_USER}@${RSYNC_HOST} "ls -ld ${RSYNC_PATH}/${RSYNC_PREFIX}/backup" >/dev/null 2>&1 \
		    || Error "Archive not found on [$RSYNC_USER@$RSYNC_HOST:${RSYNC_PATH}/${RSYNC_PREFIX}]"
		;;

	(rsync)
		$BACKUP_PROG "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/backup" >/dev/null 2>&1 \
		    || Error "Archive not found on [$RSYNC_USER@$RSYNC_HOST:${RSYNC_PATH}/${RSYNC_PREFIX}]"
		;;
esac
