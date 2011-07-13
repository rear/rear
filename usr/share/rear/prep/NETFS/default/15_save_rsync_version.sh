case $(basename $BACKUP_PROG) in

	(rsync)
		# $TMP_DIR/rsync_protocol used by 20_selinux_in_use.sh script
		$BACKUP_PROG --version > "$TMP_DIR/rsync_protocol" 2>&1
		;;

	(*)
		: # no action required
		;;

esac
