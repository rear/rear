
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

# When the RESTORE_ARCHIVES array is not empty, there is no need to disrupt
# "rear recover" or "rear restoreonly" and ask the user for the backup archive.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
test "${RESTORE_ARCHIVES[*]}" && return

# Detect all backups on the USB device.
# TODO: This fails when the backup archive name is not
# ${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}
# so that in particular it fails for incremental/differential backups
# but incremental/differential backups usually require several backup archives
# to be restored (one full backup plus one differential or several incremental backups)
# cf. RESTORE_ARCHIVES in usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# and the backup selection code below only works to select one single backup archive:
backups=()
backup_times=()
for rear_run in $BUILD_DIR/outputfs/rear/$HOSTNAME/* ; do
    Debug "Relax-and-Recover run '$rear_run' detected."
    backup_name=$rear_run/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}
    if test -r "$backup_name" ; then
        LogPrint "Backup archive $backup_name detected."
        backups=( "${backups[@]}" "$backup_name" )
        backup_times=( "${backup_times[@]}" "${rear_run##*/}" )
    fi
done

# When there is only one backup archive detected use that and do not disrupt
# "rear recover" or "rear restoreonly" and ask the user for the backup archive:
if test "1" = "${#backups[@]}" ; then
    backuparchive=${backups[0]}
    LogPrint "Using backup archive '$backuparchive'."
    return
fi

# Let the user has choose the backup:
LogPrint "Select a backup archive."
select choice in "${backup_times[@]}" "Abort" ; do
    test "Abort" = "$choice" && Error "User chose to abort recovery."
    n=( $REPLY ) # trim blanks from reply
    let n-- # because bash arrays count from 0
    if [ "$n" -lt 0 ] || [ "$n" -ge "${#backup_times[@]}" ] ; then
        LogPrint "Invalid choice $REPLY, try again or abort."
        continue
    fi
    backuparchive=${backups[$n]}
    LogPrint "Using backup archive '$backuparchive'."
    break
done 2>&1

