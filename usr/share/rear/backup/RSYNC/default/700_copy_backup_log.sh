# copy the backup.log & rear.log file to remote destination with timestamp added
Timestamp=$(date +%Y%m%d.%H%M)

# compress the log file first
gzip "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
StopIfError "Could not gzip ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"

case $RSYNC_PROTO in

	(ssh)
		$BACKUP_PROG -a "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log.gz" \
		"${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/${BACKUP_PROG_ARCHIVE}-${Timestamp}.log.gz" 2>/dev/null

		$BACKUP_PROG -a "$RUNTIME_LOGFILE" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/rear-${Timestamp}.log" 2>/dev/null
		;;

	(rsync)
		$BACKUP_PROG -a "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log.gz" ${BACKUP_RSYNC_OPTIONS[@]} \
		"${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/${BACKUP_PROG_ARCHIVE}-${Timestamp}.log.gz"

		$BACKUP_PROG -a "$RUNTIME_LOGFILE" ${BACKUP_RSYNC_OPTIONS[@]} "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}//rear-${Timestamp}.log"
		;;

esac

