### Determine the name of the backup archive
### This needs to be after we special case USB devices.

local scheme=$(url_scheme $BACKUP_URL)
case "$TAPE_DEVICE:$scheme" in
    (:file|:iso)
        # define the output path according to the scheme
        local path=$(url_path $BACKUP_URL)
        local opath=$(backup_path $scheme $path)
        backuparchive="${opath}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
        ;;
    (:*)
        if [ "$BACKUP_TYPE" == "incremental" ]; then
            for i in $(ls ${BUILD_DIR}/outputfs/${NETFS_PREFIX}/*.tar.gz); do restorearchive=$i;done
            if [ $(date +%a) = $FULLBACKUPDAY ]; then
                Log "It is Full-Backup-Day"
                rm -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt"
            fi

            if [ -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt" ]; then
                BASEBACKUP=$(cat "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/basebackup.txt"| cut -b -10)
                if [ "$(date +%Y%m%d --date="7 days ago")" -gt $(echo "$BASEBACKUP" | tr -d "-") ]; then
                    Log "Last Full-Backup too old - Performing Full-Backup"
                    rm -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt"
                fi
            fi

            if [ ! -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/basebackup.txt" ]; then
                rm -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt"
                Log "Timestamp-Files screwd - Performing Full-Backup"
            else
                BASEBACKUP=$(cat "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/basebackup.txt")
                if [ ! -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/$BASEBACKUP" ]; then
                    rm -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt"
                        Log "Last Fullbackup not found - Performing Full-Backup"
                fi
            fi

            if [ -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt" ]; then
                backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/$(date +"%Y-%m-%d-%H%M")-I${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
                BACKUP_PROG_X_OPTIONS="$BACKUP_PROG_X_OPTIONS --newer=$(cat ${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt)"
                BACKUP_PROG_X_OPTIONS="$BACKUP_PROG_X_OPTIONS -V $(cat ${BUILD_DIR}/outputfs/${NETFS_PREFIX}/basebackup.txt)"
                Log "Performing Incremental-Backup $backuparchive"
            else
                backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/$(date +"%Y-%m-%d-%H%M")-F${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
                date '+%Y-%m-%d' > "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/timestamp.txt"
                echo "$(date +"%Y-%m-%d-%H%M")-F${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}" > "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/basebackup.txt"
                BACKUP_PROG_X_OPTIONS="$BACKUP_PROG_X_OPTIONS -V $(date +"%Y-%m-%d-%H%M")-F${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
                Log "Performing Full-Backup $backuparchive"
            fi
       else
               backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
               restorearchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
       fi
        ;;
    (*:tape)
        backuparchive="${TAPE_DEVICE}"
        ;;
esac
