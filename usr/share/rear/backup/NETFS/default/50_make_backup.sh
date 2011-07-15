# 50_make_backup.sh
#

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $TMP_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $TMP_DIR/backup-exclude.txt

mkdir -p $v "${BUILD_DIR}/netfs/${NETFS_PREFIX}" >&2

LogPrint "Creating $BACKUP_PROG archive '$backuparchive'"
ProgressStart "Preparing archive operation"
(
case "$BACKUP_PROG" in
	# tar compatible programs here
	(tar)
		$BACKUP_PROG --sparse --block-number --totals --verbose --no-wildcards-match-slash --one-file-system --ignore-failed-read \
			$BACKUP_PROG_OPTIONS ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} $BACKUP_PROG_COMPRESS_OPTIONS \
			-X $TMP_DIR/backup-exclude.txt -C / -c -f "$backuparchive" \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE
	;;
	(rsync)
		# make sure that the target is a directory
		mkdir -p $v "$backuparchive" >&2
		$BACKUP_PROG --sparse --archive --hard-links --one-file-system --verbose --delete --numeric-ids \
			--exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
			$(cat $TMP_DIR/backup-include.txt) "$backuparchive"
	;;
	(*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
			$BACKUP_PROG_OPTIONS $backuparchive \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE > $backuparchive
	;;
esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
# important trick: the backup prog is the last in each case entry and the case .. esac is the last command
# in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog!
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# return disk usage in bytes
function get_disk_used() {
	let "$(stat -f -c 'used=(%b-%f)*%S' $1)"
	echo $used
}
# while the backup runs in a sub-process, display some progress information to the user
case "$BACKUP_PROG" in
	(tar)
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			blocks="$(tail -1 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }')"
			size="$((blocks*512))"
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			echo "INFO Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]" >&8
		done
		;;
	(rsync)
		# since we do not want to do a $(du -s) run every second we count disk usage instead
		# this obviously leads to wrong results in case something else is writing to the same
		# disk at the same time as is very likely with a networked file system. For local disks
		# this should be good enough and in any case this is only some eye candy.
		# TODO: Find a fast way to count the actual transfer data, preferrable getting the info from rsync.
		let old_disk_used="$(get_disk_used "$backuparchive")"
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			let disk_used="$(get_disk_used "$backuparchive")" size=disk_used-old_disk_used
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			echo "INFO Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]" >&8
		done
		;;
	(*)
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			size="$(stat -c "%s" "$backuparchive")" || {
				kill -9 $BackupPID
				ProgressError
				Error "The backup program did not create the archive file !
Killed the backup program and aborting."
			}
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			echo "INFO Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]" >&8
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
# everyone should see this warning, even if not verbose
test "$backup_prog_rc" -gt 0 && VERBOSE=1 LogPrint "WARNING !
There was an error (Nr. $backup_prog_rc) during archive creation.
Please check the archive and see '$LOGFILE' for more information.

Since errors are oftenly related to files that cannot be saved by
$BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !

"

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $backup_prog_rc -eq 0 -a "$tar_message" ] ; then
	LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

### Copy progress log to backup media
cp $v "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${BUILD_DIR}/netfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}.log" >&2
