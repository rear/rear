# 540_choose_backup.sh

[[ -z "$BACKUP_RSYNC_RETENTION_DAYS" ]] && return   # empty means no retention is requested

local fullpath host

host="$(rsync_host "$BACKUP_URL")"

fullpath="$(rsync_path "${BACKUP_URL}")"/${RSYNC_PREFIX}/backup/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]

ssh $(rsync_remote_ssh $BACKUP_URL) "ls -d $fullpath" > $TMP_DIR/backup.dirs

# File exists and has a size greater than zero
[[ -s $TMP_DIR/backup.dirs ]] || Error "We were not able to retrieve backup information on $host"

# Detect all backups in the specified location
backups=()

for backup in $(cat $TMP_DIR/backup.dirs) ;do
    Debug "RSYNC backup $backup detected."
    backups+=( ${backup##*/} )  # store date into array backups
done

(( ${#backups[@]} > 0 ))
StopIfError "No RSYNC backups available."

# The user has to choose from the backup list to overrule default value of RSYNC_BACKUP
LogPrint "Select a backup to restore."
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _framework-setup-and-functions.sh):
select choice in "${backups[@]}" "Abort"; do
    [ "$choice" != "Abort" ]
    StopIfError "User chose to abort recovery."
    n=( $REPLY ) # trim blanks from reply
    let n-- # because bash arrays count from 0
    if [ "$n" -lt 0 ] || [ "$n" -ge "${#backups[@]}" ] ; then
        LogPrint "Invalid choice $REPLY, please try again or abort."
        continue
    fi
    LogPrint "Backup ${backups[$n]} chosen."
    RSYNC_BACKUP=${backups[$n]}  # yyyy-mm-dd
    break
done 0<&6 1>&7 2>&8
