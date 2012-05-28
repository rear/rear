### Determine the name of the backup archive
### This needs to be after we special case USB devices.

local scheme=$(url_scheme $BACKUP_URL)
case "$TAPE_DEVICE:$scheme" in
    (:file)
        # define the output path according to the scheme
        local path=$(url_path $BACKUP_URL)
        local opath=$(output_path $scheme $path)
        backuparchive="${opath}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
        ;;
    (:*)
        backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
        ;;
    (*:tape)
        backuparchive="${TAPE_DEVICE}"
        ;;
esac
