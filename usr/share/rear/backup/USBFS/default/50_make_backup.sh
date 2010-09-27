# #20_make_backup.sh
#

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $BUILD_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $BUILD_DIR/backup-exclude.txt


Log "Creating archive '$backuparchive'"
Print "Creating archive '$displayarchive'"
counter=1
lasttime=$SECONDS
starttime=$lasttime
lastsize=0
speed=unknown
echo -n "Backing up"
(
case "$BACKUP_PROG" in
	# tar compatible programs here
	tar)
		$BACKUP_PROG --sparse --verbose --no-wildcards-match-slash --one-file-system --ignore-failed-read \
			$BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS \
			-X $BUILD_DIR/backup-exclude.txt -C / -c -f "$backuparchive" \
			$(cat $BUILD_DIR/backup-include.txt)
	;;
	*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $BUILD_DIR/backup-exclude.txt \
			$BACKUP_PROG_OPTIONS $backuparchive \
			$(cat $BUILD_DIR/backup-include.txt) > $backuparchive
	;;
esac >"${BUILD_DIR}/netfs/${BACKUP_PROG_ARCHIVE}.txt"
echo $? >$BUILD_DIR/retval
) &
BackupPID=$!

sleep 1 # Give the backup software a good chance to start working

# while the backup runs in a sub-process, display some progress information to the user
while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
	size="$(stat -c "%s" "$backuparchive")" || {
		kill -9 $BackupPID
		. $SHARE_DIR/backup/USB/default/98_umount_USB.sh
		Error "The backup program did not create the archive file !
Killing the backup program and aborting. "
	}
	#let size=size/1024/1024
	let speed=size-lastsize # / 1 second
	let lastsize=size
	printf "\r%-60s" "Archive size is $((size/1024/1024)) MB [$((speed/1024)) KB/sec]"
done 
printf "\r%-62s\r" " "
size="$(stat -c "%s" "$backuparchive")"
let transfertime=SECONDS-starttime

sleep 1
test "$(cat $BUILD_DIR/retval)" -gt 0 && LogPrint "WARNING !
There was an error (Nr. $(cat $BUILD_DIR/retval)) during archive creation.
Please check the archive and see '$LOGFILE' for more information.

Since errors are oftenly related to files that cannot be saved by
$BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !

"

LogPrint "Transferred $((size/1024/1024)) MB in $((transfertime)) seconds [$((size/transfertime/1024)) KB/sec]"

