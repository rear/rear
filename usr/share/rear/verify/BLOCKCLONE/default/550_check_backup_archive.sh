# check whether the archive is actually there

# Do not check when the backup is on a tape device:
test "tape" = "$( url_scheme "$BACKUP_URL" )" && return 0

# The RESTORE_ARCHIVES array contains the restore input files.
# If it is not set, RESTORE_ARCHIVES is only one element which is the backup archive:
test "$RESTORE_ARCHIVES" || RESTORE_ARCHIVES=( "$backuparchive" )

for restoreinput in "${RESTORE_ARCHIVES[@]}" ; do

    local backup_splitted_file="$( dirname $restoreinput )/backup.splitted"
    local restoreinput_filename="$( basename $restoreinput )"

    test -s "$restoreinput" -o -d "$restoreinput" -o -f "$backup_splitted_file" || Error "Backup archive '$restoreinput_filename' not found."

    LogPrint "Calculating backup archive size"
    if test -f "$backup_splitted_file" ; then
        cut -d ' ' -f2 "$backup_splitted_file" | awk '{s+=$1} END {print s/(1024*1024)"M"}' >$TMP_DIR/backuparchive_size
    else
        du -sh "$restoreinput" | cut -d ' ' -f1 >$TMP_DIR/backuparchive_size
    fi
    read backuparchive_size <$TMP_DIR/backuparchive_size
    test "$backuparchive_size" && LogPrint "Backup archive size is $backuparchive_size ${BACKUP_PROG_COMPRESS_SUFFIX:+(compressed)}"

    if is_true "$BACKUP_INTEGRITY_CHECK" && test -f $restoreinput.md5 ; then
        if ! test -f "$backup_splitted_file" ; then
            LogPrint "Checking integrity of $restoreinput_filename"
            pushd ${restoreinput%/*}
            md5sum -c $restoreinput.md5 || Error "Integrity check failed. Restore aborted because BACKUP_INTEGRITY_CHECK is enabled."
            popd
        fi
    fi
done

