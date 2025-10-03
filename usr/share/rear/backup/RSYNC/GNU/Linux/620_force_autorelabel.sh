local backup_prog_rc

[ -f $TMP_DIR/force.autorelabel ] && {

	> "${TMP_DIR}/selinux.autorelabel"

	case $(rsync_proto "$BACKUP_URL") in

	(ssh)
		# for some reason rsync changes the mode of backup after each run to 666
                # FIXME: Add an explanatory comment why "2>/dev/null" is useful here
                # or remove it according to https://github.com/rear/rear/issues/1395
		ssh $(rsync_remote_ssh "$BACKUP_URL") "chmod $v 755 $(rsync_path_full "$BACKUP_URL")/backup" 2>/dev/null
		$BACKUP_PROG -a "${TMP_DIR}/selinux.autorelabel" \
		 "$(rsync_remote_full "$BACKUP_URL")/backup/.autorelabel" 2>/dev/null
		backup_prog_rc=$?
		if [ $backup_prog_rc -ne 0 ]; then
			LogPrint "Failed to create .autorelabel on $(rsync_path_full "$BACKUP_URL")/backup [${rsync_err_msg[$backup_prog_rc]}]"
			#StopIfError "Failed to create .autorelabel on $(rsync_path_full "$BACKUP_URL")/backup"
		fi
		;;

	(rsync)
		$BACKUP_PROG -a "${TMP_DIR}/selinux.autorelabel" "${BACKUP_RSYNC_OPTIONS[@]}" \
		 "$(rsync_remote_full "$BACKUP_URL")/backup/.autorelabel"
		backup_prog_rc=$?
		if [ $backup_prog_rc -ne 0 ]; then
			LogPrint "Failed to create .autorelabel on $(rsync_path_full "$BACKUP_URL")/backup [${rsync_err_msg[$backup_prog_rc]}]"
			#StopIfError "Failed to create .autorelabel on $(rsync_path_full "$BACKUP_URL")/backup"
		fi
		;;

	esac
	Log "Trigger (forced) autorelabel (SELinux) file"
}

