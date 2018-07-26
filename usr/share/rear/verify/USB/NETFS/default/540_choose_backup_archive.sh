
# In case of backup restore from USB let the user choose which backup will be restored.
# This script is only run during a backup restore workflow (recover/restoreoly)
# so that RESTORE_ARCHIVES is set in this script.

scheme=$( url_scheme "$BACKUP_URL" )
# Skip if not backup on USB:
test "usb" = "$scheme" || return 0

# When USB_SUFFIX is set the compliance mode is used where
# backup on USB works in compliance with backup on NFS which means
# a fixed backup directory where the user cannot choose the backup
# because what there is in the fixed backup directory will be restored
# via RESTORE_ARCHIVES set by usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# Use plain $USB_SUFFIX and not "$USB_SUFFIX" because when USB_SUFFIX contains only blanks
# test "$USB_SUFFIX" would result true because test " " results true:
test $USB_SUFFIX && return

# When backup on USB works in its default mode with several timestamp backup directories
# let the user choose the backup regardless whether or not RESTORE_ARCHIVES
# is already set by usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# because when the user has created a backup plus recovery system via "rear mkbackup"
# and afterwards a newer backup without recovery system via "rear mkbackuponly"
# then the recovery system directory contains the (older) backup and that one gets
# set in RESTORE_ARCHIVES by usr/share/rear/prep/NETFS/default/070_set_backup_archive.sh
# but probably the user wants to choose the newer backup to be actually restored.

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

# When there is no backup archive detected error out because in this case
# it does not make sense to show a backup selection dialog without anything to choose.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
test "${backups[*]}" || Error "No '${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}' detected in '$BUILD_DIR/outputfs/rear/$HOSTNAME/*'"

# When there is only one backup archive detected use that and do not disrupt
# "rear recover" or "rear restoreonly" with a backup selection dialog
# because what else could the user choose except that one backup:
if test "1" = "${#backups[@]}" ; then
    backuparchive=${backups[0]}
    RESTORE_ARCHIVES=( "$backuparchive" )
    LogPrint "Using backup archive '$backuparchive'."
    return
fi

# Let the user choose the backup that should be restored:
LogPrint "Select a backup archive."
# Disable printing commands and their arguments as they are executed on stderr
# which could have been enabled when running e.g. "rear -D recover"
# to not disturb the select output which also happens on stderr.
# When 'set -x' is set even calling 'set +x 2>/dev/null' would output '+ set +x' but
# http://stackoverflow.com/questions/13195655/bash-set-x-without-it-being-printed
# shows that when 'set -x' is set calling '{ set +x ; } 2>/dev/null' runs silently:
{ set +x ; } 2>/dev/null
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
select choice in "${backup_times[@]}" ; do
    # trim blanks from reply
    n=( $REPLY )
    # bash arrays count from 0
    let n--
    if [ "$n" -lt 0 ] || [ "$n" -ge "${#backup_times[@]}" ] ; then
        # direct output to stdout which is fd7 (see lib/_input-output-functions.sh)
        # and not using a Print function to always print to the original stdout
        # i.e. to the terminal wherefrom the user has started "rear recover":
        echo "Invalid choice $REPLY, try again (or press [Ctrl]+[C] to abort)." >&7
        continue
    fi
    backuparchive=${backups[$n]}
    break
done 0<&6 1>&7 2>&8
# Go back from "set +x" to the defaults:
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
RESTORE_ARCHIVES=( "$backuparchive" )
LogPrint "Using backup archive '$backuparchive'."

