# 210_find_lastbackup.sh is meant to be used when BACKUP_RSYNC_RETENTION_DAYS is non-empty (integer)

[[ -z "$BACKUP_RSYNC_RETENTION_DAYS" ]] && return   # empty means no retention is requested

# As BACKUP_RSYNC_RETENTION_DAYS only supports ssh protocol with rsync we do not need to check the protocol again
# as in prep/RSYNC/GNU/Linux/210_rsync_retention_days.sh we perform the explicit check already.

local fullpath
local rsyncbackup

fullpath="$(rsync_path "${BACKUP_URL}")"/${RSYNC_PREFIX}/backup/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]

# $TMP_DIR/backup.dirs contains a list of RSYNC backups taking on certain dates, e.g.
# /var/services/homes/gdha/rsync/rocky/backup/2026-01-27

ssh $(rsync_remote_ssh $BACKUP_URL) "ls -d $fullpath" > $TMP_DIR/backup.dirs
if [[ $? -ne 0 ]] ; then
    # Something went wrong with the ssh command
    LogPrintError "ssh $(rsync_remote_ssh $BACKUP_URL) ls -d $fullpath failed."
    # We dare not to exit, but define today's lastrsyncbackup path instead.
    lastrsyncbackup="$(rsync_path "${BACKUP_URL}")"/${RSYNC_PREFIX}/backup/${RSYNC_TODAY}
    rm -f $TMP_DIR/backup.dirs # remove empty file
    return
fi

# When $TMP_DIR/backup.dirs contains data we will reuse this file later to see if we need to remove an old
# backup when we have more backups in the list then BACKUP_RSYNC_RETENTION_DAYS
rsyncbackup=( $(cat $TMP_DIR/backup.dirs | grep -v $RSYNC_TODAY | sort) ) # array contains full path of all backups

if [[ ${#rsyncbackups[@]} -gt 0 ]] ; then
    lastrsyncbackup="${rsyncbackups[${#rsyncbackups[@]}-1]}" # last value in array
else
    # If no lastrsyncbackup is found, then set the same dir as current backup target (RSYNC_TODAY).
    # In any case we will make a full backup.
    lastrsyncbackup="$(rsync_path "${BACKUP_URL}")"/${RSYNC_PREFIX}/backup/${RSYNC_TODAY}
fi
# Be aware $lastrsyncbackup contains a full path of the destination system and can be used as such.
