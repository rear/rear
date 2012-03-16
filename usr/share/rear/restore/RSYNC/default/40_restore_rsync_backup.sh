# Restore the remote backup via RSYNC

get_size() {
	echo $(stat --format '%s' "/mnt/local/$1")
}

mkdir -p "${TMP_DIR}/rsync/${NETFS_PREFIX}"
StopIfError "Could not mkdir '$TMP_DIR/rsync/${NETFS_PREFIX}'"

LogPrint "Restoring $BACKUP_PROG archive from '${RSYNC_HOST}:${RSYNC_PATH}'"

ProgressStart "Restore operation"
(
	case "$(basename $BACKUP_PROG)" in

		(rsync)

			case $RSYNC_PROTO in

				(ssh)
					Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ /mnt/local/
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" \
					"${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ \
					/mnt/local/
					;;

				(rsync)
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" \
					"${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/backup"/ /mnt/local/
					;;

			esac
			;;

		(*)
			# no other backup programs foreseen then rsync so far
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
case "$(basename $BACKUP_PROG)" in
	(rsync)
		
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			fsize=$(get_size "$(tail -2 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | head -n 1)")
			size=$((size+fsize))
			ProgressInfo "Restored $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;

	(*)

		ProgressInfo "Restoring"
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			ProgressStep
		done
		;;
esac
ProgressStop

transfertime="$((SECONDS-starttime))"

# harvest return code from background job. The kill -0 $BackupPID loop above should
# have made sure that this wait won't do any real "waiting" :-)
wait $BackupPID
_rc=$?

sleep 1
test "$_rc" -gt 0 && LogPrint "WARNING !
There was an error (${rsync_err_msg[$_rc]}) while restoring the archive.
Please check '$LOGFILE' for more information. You should also
manually check the restored system to see wether it is complete.
"

_message="$(tail -14 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log)"

if [ $_rc -eq 0 -a "$_message" ] ; then
        LogPrint "$_message in $transfertime seconds."
elif [ "$size" ]; then
        LogPrint "Restored $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi
