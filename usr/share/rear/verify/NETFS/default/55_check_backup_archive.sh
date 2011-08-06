# check wether the archive is actually there

# Don't check when backup is on a tape device
case $(url_scheme "$BACKUP_URL") in
    (tape)
        return 0
        ;;
esac

[ -s "$backuparchive" -o -d "$backuparchive" ]
StopIfError "Backup archive '$backuparchive' not found !"

LogPrint "Calculating backup archive size"

du -sh "$backuparchive" >$TMP_DIR/backuparchive_size
StopIfError "Failed to determine backup archive size."

read backuparchive_size junk <$TMP_DIR/backuparchive_size
LogPrint "Backup archive size is $backuparchive_size${BACKUP_PROG_COMPRESS_SUFFIX:+ (compressed)}"
