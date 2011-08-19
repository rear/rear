# copy the restore log to restored system /mnt/local/root/ with a timestamp

if ! test -d /mnt/local/root ; then
	mkdir -p /mnt/local/root
	chmod 0700 /mnt/local/root
fi

cp "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" /mnt/local/root/restore-$(date +%Y%m%d.%H%M).log
StopIfError "Could not copy ${BACKUP_PROG_ARCHIVE}-restore.log to /mnt/local/root"
gzip "/mnt/local/root/restore-$(date +%Y%m%d.)*.log"

# the rear.log file will be copied later (by wrapup/default/99_copy_logfile.sh)
