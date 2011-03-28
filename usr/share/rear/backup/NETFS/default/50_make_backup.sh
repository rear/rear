# 50_make_backup.sh
#

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $BUILD_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $BUILD_DIR/backup-exclude.txt

mkdir -p "${BUILD_DIR}/netfs/${NETFS_PREFIX}"

Log "Creating archive '$backuparchive'"
Print "Creating archive '$displayarchive'"
echo -n "Preparing archive operation"
(
case "$BACKUP_PROG" in
	# tar compatible programs here
	tar)
		$BACKUP_PROG --sparse --block-number --totals --verbose --no-wildcards-match-slash --one-file-system --ignore-failed-read \
			$BACKUP_PROG_OPTIONS ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} $BACKUP_PROG_COMPRESS_OPTIONS \
			-X $BUILD_DIR/backup-exclude.txt -C / -c -f "$backuparchive" \
			$(cat $BUILD_DIR/backup-include.txt) $LOGFILE
	;;
	*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $BUILD_DIR/backup-exclude.txt \
			$BACKUP_PROG_OPTIONS $backuparchive \
			$(cat $BUILD_DIR/backup-include.txt) $LOGFILE > $backuparchive
	;;
esac >"${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log"
echo $? >$BUILD_DIR/retval
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# while the backup runs in a sub-process, display some progress information to the user
case "$BACKUP_PROG" in
	tar)
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			blocks="$(tail -1 ${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }')"
			size="$((blocks*512))"
			echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		echo -en "\e[2K\r"
		;;
	*)
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			size="$(stat -c "%s" "$backuparchive")" || {
				kill -9 $BackupPID
				. $SHARE_DIR/backup/NETFS/default/71_umount_NETFS_dir.sh
				Error "The backup program did not create the archive file !"
				Error "Killing the backup program and aborting."
			}
			echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		echo -en "\e[2K\r"
		;;
esac

transfertime="$((SECONDS-starttime))"
tar_rc="$(cat $BUILD_DIR/retval)"

sleep 1
test "$tar_rc" -gt 0 && LogPrint "WARNING !
There was an error (Nr. $(cat $BUILD_DIR/retval)) during archive creation.
Please check the archive and see '$LOGFILE' for more information.

Since errors are oftenly related to files that cannot be saved by
$BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !

"

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $tar_rc -eq 0 -a "$tar_message" ] ; then
	LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

### Move progress log to backup media
mv "${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${BUILD_DIR}/netfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}.log"
