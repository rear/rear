
# In case of backup on USB let the user choose which backup will be restored.

scheme=$( url_scheme "$BACKUP_URL" )
# Skip if not backup on USB:
test "usb" = "$scheme" || return

# When USB_SUFFIX is set the compliance mode is used where
# backup on USB works in compliance with backup on NFS which means
# a fixed backup directory where the user cannot choose the backup
# because what there is in the fixed backup directory will be restored
# via RESTORE_ARCHIVES in usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# Use plain $USB_SUFFIX and not "$USB_SUFFIX" because when USB_SUFFIX contains only blanks
# test "$USB_SUFFIX" would result true because test " " results true:
test $USB_SUFFIX && return

# Detect all backups on the USB device.
# FIXME: This fails when the backup archive name is not
# ${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}
# so that in particular it fails for incremental/differential backups
# but incremental/differential backups usually require several backup archives
# to be restored (one full backup plus one differential or several incremental backups)
# cf. RESTORE_ARCHIVES in usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# and the code below only works for one single backup archive:
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

