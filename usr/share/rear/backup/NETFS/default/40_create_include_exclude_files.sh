# backup all local filesystems, as defined in mountpoint_device

for k in "${BACKUP_PROG_INCLUDE[@]}" ; do
	test "$k" && echo "$k"
done > $TMP_DIR/backup-include.txt
# add the mountpoints that will be recovered to the backup include list
while read mountpoint device junk ; do
	if ! IsInArray "$mountpoint" "${EXCLUDE_MOUNTPOINTS[@]}" ; then
		echo "$mountpoint"
	fi
done <"$VAR_DIR/recovery/mountpoint_device" >> $TMP_DIR/backup-include.txt

# exclude list
for k in "${BACKUP_PROG_EXCLUDE[@]}" ; do
	test "$k" && echo "$k"
done > $TMP_DIR/backup-exclude.txt
# add also the excluded mount points to the backup exclude list
for k in "${EXCLUDE_MOUNTPOINTS[@]}" ; do
	test "$k" && echo "$k/"
done >> $TMP_DIR/backup-exclude.txt

