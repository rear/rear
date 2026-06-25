# 600_remove_old_rsync_backup.sh
# When we use rsync with retention days then w emight need to remove a backup above the BACKUP_RSYNC_RETENTION_DAYS value

[[ -z "$BACKUP_RSYNC_RETENTION_DAYS" ]] && return   # empty means no retention is requested

[[ ! -f $TMP_DIR/backup.dirs ]] && return  # the list was empty or non-existing, nothing to remove

local rsyncbackup
local host

host="$(rsync_host "$BACKUP_URL")"

rsyncbackup=( $(cat $TMP_DIR/backup.dirs | grep -v $RSYNC_TODAY | sort) ) # array contains full path of all backups

# We start to count from 0 in an array
if [[ ${#rsyncbackup[@]} -ge $BACKUP_RSYNC_RETENTION_DAYS ]] ; then
    # the first in the array list is the oldest rsync path
    remove_rsync_backup_path="${rsyncbackup[0]}"
else
    # nothing to remove; just return
    return
fi

# Now we can remove the $remove_rsync_backup_path on the remote server

LogPrint "Removing oldest RSYNC backup directory $remove_rsync_backup_path on $host"
ssh $(rsync_remote_ssh "$BACKUP_URL") "[[ -d $remove_rsync_backup_path ]] && rm -rf $remove_rsync_backup_path"
