# 40_restore_backup.sh
#

mkdir -p "${BUILD_DIR}/netfs/${NETFS_PREFIX}"

Log "Restoring archive '$backuparchive'"
Print "Restoring from '$displayarchive'"
echo -n "Preparing restore operation"
(
case "$BACKUP_PROG" in
	# tar compatible programs here
	(tar)
		$BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS \
			-C /mnt/local/ -x -f "$backuparchive"
	;;
	(rsync)
		$BACKUP_PROG --sparse --archive --hard-links --verbose $BACKUP_PROG_OPTIONS \
			"$backuparchive"/ /mnt/local/
	;;
	(*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE /mnt/local \
			$BACKUP_PROG_OPTIONS $backuparchive
	;;
esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log"
echo $? >$BUILD_DIR/retval
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# while the backup runs in a sub-process, display some progress information to the user
case "$BACKUP_PROG" in
	tar)
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			blocks="$(tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }')"
			size="$((blocks*512))"
			echo -en "\e[2K\rRestored $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		echo -en "\e[2K\r"
		;;
	*)
		ProgressStart "Restoring archive"
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			ProgressStep
		done
		;;
esac

transfertime="$((SECONDS-starttime))"
tar_rc="$(cat $BUILD_DIR/retval)"

sleep 1
test "$tar_rc" -gt 0 && LogPrint "WARNING !
There was an error (Nr. $(cat $BUILD_DIR/retval)) while restoring the archive. 
Please check '$LOGFILE' for more information. You should also
manually check the restored system to see wether it is complete.
"

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $tar_rc -eq 0 -a "$tar_message" ] ; then
	LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Restored $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi
