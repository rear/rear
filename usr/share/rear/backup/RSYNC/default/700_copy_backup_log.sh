
# copy the backup.log & rear.log file to remote destination with timestamp added
local timestamp proto

timestamp=$( date +%Y%m%d.%H%M )
proto="$(rsync_proto "$BACKUP_URL")"

# compress the log file first
gzip "$TMP_DIR/$BACKUP_PROG_ARCHIVE.log" || Error "Failed to 'gzip $TMP_DIR/$BACKUP_PROG_ARCHIVE.log'"

case $proto in
    (ssh)
        # FIXME: Add an explanatory comment why "2>/dev/null" is useful here
        # or remove it according to https://github.com/rear/rear/issues/1395
        $BACKUP_PROG -a "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log.gz" \
        "$(rsync_remote_full "$BACKUP_URL")/${BACKUP_PROG_ARCHIVE}-${timestamp}.log.gz" 2>/dev/null

        $BACKUP_PROG -a "$RUNTIME_LOGFILE" "$(rsync_remote_full "$BACKUP_URL")/rear-${timestamp}.log" 2>/dev/null
        ;;
    (rsync)
        $BACKUP_PROG -a "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log.gz" "${BACKUP_RSYNC_OPTIONS[@]}" \
        "$(rsync_remote_full "$BACKUP_URL")/${BACKUP_PROG_ARCHIVE}-${timestamp}.log.gz"

        $BACKUP_PROG -a "$RUNTIME_LOGFILE" "${BACKUP_RSYNC_OPTIONS[@]}" "$(rsync_remote_full "$BACKUP_URL")//rear-${timestamp}.log"
        ;;
esac

