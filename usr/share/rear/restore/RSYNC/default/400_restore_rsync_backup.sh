# Restore the remote backup via RSYNC

get_size() {
	echo $( stat --format '%s' "$TARGET_FS_ROOT/$1" )
}

local backup_prog_rc
local restore_log_message

mkdir -p "${TMP_DIR}/rsync/${NETFS_PREFIX}"
StopIfError "Could not mkdir '$TMP_DIR/rsync/${NETFS_PREFIX}'"

LogPrint "Restoring $BACKUP_PROG archive from '${RSYNC_HOST}:${RSYNC_PATH}'"

ProgressStart "Restore operation"
(
	case "$(basename $BACKUP_PROG)" in

		(rsync)

			case $RSYNC_PROTO in

				(ssh)
					Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ $TARGET_FS_ROOT/
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" \
					"${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ \
					$TARGET_FS_ROOT/
					;;

				(rsync)
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" \
					"${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ $TARGET_FS_ROOT/
					;;

			esac
			;;

		(*)
			# no other backup programs foreseen than rsync so far
			:
			;;

	esac
	echo $? >$TMP_DIR/retval
) >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" &
BackupPID=$!
starttime=$SECONDS

sleep 3 # Give the backup software a good chance to start working

# make sure that we don't fall for an old size info
unset size
# while the restore runs in a sub-process, display some progress information to the user
test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
case "$(basename $BACKUP_PROG)" in
	(rsync)
		
		while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
			fsize=$(get_size "$(tail -2 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | head -n 1)")
			size=$((size+fsize))
			ProgressInfo "Restored $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;

	(*)

		ProgressInfo "Restoring"
		while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
			ProgressStep
		done
		;;

esac
ProgressStop

transfertime="$((SECONDS-starttime))"

# harvest return code from background job. The kill -0 $BackupPID loop above should
# have made sure that this wait won't do any real "waiting" :-)
wait $BackupPID || LogPrintError "Restore job returned a nonzero exit code $?"
# harvest the actual return code of rsync. Finishing the pipeline with an error code above is actually unlikely,
# because rsync is not the last command in it. But error returns from rsync are common and must be handled.
backup_prog_rc="$(cat $TMP_DIR/retval)"

sleep 1
test "$backup_prog_rc" -gt 0 && LogPrintError "WARNING !
There was an error (${rsync_err_msg[$backup_prog_rc]}) while restoring the archive.
Please check '$RUNTIME_LOGFILE' for more information. You should also
manually check the restored system to see whether it is complete.
"

restore_log_message="$(tail -14 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log)"

if [ $backup_prog_rc -eq 0 -a "$restore_log_message" ] ; then
        LogPrint "$restore_log_message in $transfertime seconds."
elif [ "$size" ]; then
        LogPrint "Restored $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi
