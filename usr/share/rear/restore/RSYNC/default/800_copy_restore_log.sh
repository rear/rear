# copy the restore log to restored system $TARGET_FS_ROOT/root/ with a timestamp

if ! test -d $TARGET_FS_ROOT/$ROOT_HOME_DIR ; then
	mkdir -p $TARGET_FS_ROOT/$ROOT_HOME_DIR
	chmod 0700 $TARGET_FS_ROOT/$ROOT_HOME_DIR
fi

cp "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" $TARGET_FS_ROOT/$ROOT_HOME_DIR/restore-$(date +%Y%m%d.%H%M).log
StopIfError "Could not copy ${BACKUP_PROG_ARCHIVE}-restore.log to $TARGET_FS_ROOT/$ROOT_HOME_DIR"
gzip "$TARGET_FS_ROOT/$ROOT_HOME_DIR/restore-$(date +%Y%m%d.)*.log"

# the rear.log file will be copied later (by wrapup/default/990_copy_logfile.sh)
