# 40_restore_backup.sh
#

mkdir -p "${BUILD_DIR}/outputfs/${NETFS_PREFIX}"

Log "Restoring $BACKUP_PROG archive '$backuparchive'"
Print "Restoring from '$backuparchive'"
ProgressStart "Preparing restore operation"
(
case "$BACKUP_PROG" in
	# tar compatible programs here
	(tar)
		if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
			BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --exclude-from=$TMP_DIR/restore-exclude-list.txt "
		fi
		Log $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS \
			-C /mnt/local/ -x -f "$backuparchive"
		$BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS \
			-C /mnt/local/ -x -f "$backuparchive"
	;;
	(rsync)
		if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
			BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --exclude-from=$TMP_DIR/restore-exclude-list.txt "
		fi
		Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $BACKUP_PROG_OPTIONS "$backuparchive"/ /mnt/local/
		$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $BACKUP_PROG_OPTIONS \
			"$backuparchive"/ /mnt/local/
	;;
	(*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE /mnt/local \
			$BACKUP_PROG_OPTIONS $backuparchive
	;;
esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log"
# important trick: the backup prog is the last in each case entry and the case .. esac is the last command
# in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog!
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# make sure that we don't fall for an old size info
unset size
# while the backup runs in a sub-process, display some progress information to the user
case "$BACKUP_PROG" in
	tar)
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			blocks="$(tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }')"
			size="$((blocks*512))"
			ProgressInfo "Restored $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;
	*)
		ProgressInfo "Restoring..."
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
backup_prog_rc=$?

sleep 1
test "$backup_prog_rc" -gt 0 && LogPrint "WARNING !
There was an error (Nr. $backup_prog_rc) while restoring the archive.
Please check '$LOGFILE' for more information. You should also
manually check the restored system to see wether it is complete.
"

# TODO if size is not given then calculate it from backuparchive_size

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $backup_prog_rc -eq 0 -a "$tar_message" ] ; then
	LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Restored $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi
