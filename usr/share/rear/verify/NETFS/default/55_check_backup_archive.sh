# check wether the archive is actually there

# Don't check when backup is on a tape device
if [ "$NETFS_PROTO" == "tape" ]; then
	return
fi

if [ ! -s "$backuparchive" ]; then
	Error "Backup archive '$backuparchive' not found !"
else
	ProgressStart "Calculating backup archive size"
	du -sh "$backuparchive" >$TMP_DIR/backuparchive_size &
	while kill -0 $! &>/dev/null ; do ProgressStep ; sleep 1 ; done
	wait $! # harvest return code
	ProgressStopOrError $? "Failed to determine backup archive size."
	read backuparchive_size junk <$TMP_DIR/backuparchive_size
	LogPrint "Backup archive size is $backuparchive_size${BACKUP_PROG_COMPRESS_SUFFIX:+ (compressed)}"
fi
