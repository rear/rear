
scheme=$(url_scheme "$BACKUP_URL")
if [[ "$scheme" != "usb" ]] ; then
    return
fi

# Detect all backups on the USB device
backups=()
backup_times=()
for rear_run in $BUILD_DIR/outputfs/rear/$HOSTNAME/* ;do
    Debug "Relax-and-Recover run $rear_run detected."
    backup_name=$rear_run/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}
    if [ -e $backup_name ] ; then
        Debug "Relax-and-Recover backup $backup_name detected."
        backups=( "${backups[@]}" "$backup_name")
        backup_times=( "${backup_times[@]}" "${rear_run##*/}")
    fi
done

# The user has to choose the backup
LogPrint "Select a backup archive."
select choice in "${backup_times[@]}" "Abort"; do
    [ "$choice" != "Abort" ]
    StopIfError "User chose to abort recovery."
    n=( $REPLY ) # trim blanks from reply
    let n-- # because bash arrays count from 0
    if [ "$n" -lt 0 ] || [ "$n" -ge "${#backup_times[@]}" ] ; then
        LogPrint "Invalid choice $REPLY, please try again or abort."
        continue
    fi
    LogPrint "Backup archive ${backups[$n]} chosen."
    backuparchive=${backups[$n]}
    break
done 2>&1

