# check wether the archive is actually there

if ! test -s "$backuparchive" ; then
	Error "Backup archive '$displayarchive' not found !"
else
	read size file < <(du -h "$backuparchive")
	LogPrint "Backup archive size is $size"
fi
