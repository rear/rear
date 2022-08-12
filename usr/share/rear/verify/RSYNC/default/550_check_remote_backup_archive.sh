# check the backup archive on remote rsync server

case $(rsync_proto "$BACKUP_URL") in

	(ssh)
		ssh $(rsync_remote_ssh "$BACKUP_URL") "ls -ld $(rsync_path_full "$BACKUP_URL")/backup" >/dev/null 2>&1 \
		    || Error "Archive not found on [$(rsync_remote_full "$BACKUP_URL")]"
		;;

	(rsync)
		$BACKUP_PROG "$(rsync_remote_full "$BACKUP_URL")/backup" >/dev/null 2>&1 \
		    || Error "Archive not found on [$(rsync_remote_full "$BACKUP_URL")]"
		;;
esac
