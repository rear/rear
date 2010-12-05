# check wether the archive is actually there

# Don't check when backup is on a tape device
if [ "$NETFS_PROTO" == "tape" -o "$NETFS_PROTO" == "obdr" ]; then
	return
fi

if [ ! -s "$backuparchive" ]; then
	Error "Backup archive '$displayarchive' not found !"
else
	read size file < <(du -h "$backuparchive")
	LogPrint "Backup archive size is $size"
fi
