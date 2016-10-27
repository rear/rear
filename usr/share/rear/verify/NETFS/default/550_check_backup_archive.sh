# check wether the archive is actually there

# Don't check when backup is on a tape device
case $(url_scheme "$BACKUP_URL") in
    (tape)
        return 0
        ;;
esac

if [ "$BACKUP_TYPE" == "incremental" ]; then
    backuparchive="$restorearchive"
fi

[ -s "$backuparchive" -o -d "$backuparchive" -o -f "$(dirname $backuparchive)/backup.splitted" ]
StopIfError "Backup archive '$backuparchive' not found !"

LogPrint "Calculating backup archive size"

if [[ -f "$(dirname $backuparchive)/backup.splitted" ]]; then
    cut -d ' ' -f2 "$(dirname $backuparchive)/backup.splitted" | awk '{s+=$1} END {print s/(1024*1024)"M"}' >$TMP_DIR/backuparchive_size
else
    du -sh "$restorearchive" | cut -d ' ' -f1 >$TMP_DIR/backuparchive_size
fi
StopIfError "Failed to determine backup archive size."

read backuparchive_size <$TMP_DIR/backuparchive_size
LogPrint "Backup archive size is $backuparchive_size${BACKUP_PROG_COMPRESS_SUFFIX:+ (compressed)}"

if [[ $BACKUP_INTEGRITY_CHECK =~ ^[yY1] && -f ${backuparchive}.md5 ]] ; then
    if [[ ! -f "$(dirname $backuparchive)/backup.splitted" ]]; then
        LogPrint "Checking integrity of $(basename $backuparchive) ..."
        (cd $(dirname $restorearchive) && md5sum -c ${restorearchive}.md5)
        StopIfError "Integrity check failed !! \nIf you want to bypass this check please edit the configuration file (/etc/rear/local.conf) and unset BACKUP_INTEGRITY_CHECK."
    fi
fi
