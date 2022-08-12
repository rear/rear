# here we will calculate the space required to hold the backup archive on the remote rsync system
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
local proto host path

proto="$(rsync_proto "$BACKUP_URL")"
host="$(rsync_host "$BACKUP_URL")"
path="$(rsync_path "$BACKUP_URL")"

_local_size=0
_remote_size=0
while read -r ; do
    LogPrint "Calculating size of $REPLY"
    # on Linux output is represented in 1024-blocks (or kB)
    df -Pl "$REPLY" >$TMP_DIR/fs_size
    StopIfError "Failed to determine size of $REPLY"
    fs_size=$( tail -n 1 $TMP_DIR/fs_size | awk '{print $3}' )
    _local_size=$(( _local_size + fs_size ))
done < $TMP_DIR/backup-include.txt
LogPrint "Estimated size of local file systems is $(( _local_size / 1024 )) MB"

# Commenting out next block according decision of issue #2760
#case $proto in
#    (ssh)
#        LogPrint "Calculating size of ${host}:${path}"
#        ssh $(rsync_remote_ssh "$BACKUP_URL") "df -P ${path}" >$TMP_DIR/rs_size
#        StopIfError "Failed to determine size of ${path}"
#        _div=1 # 1024-blocks
#        grep -q "512-blocks" $TMP_DIR/rs_size && _div=2 # HPUX: divide with 2 to get kB size
#        _remote_size=$( tail -n 1 $TMP_DIR/rs_size | awk '{print $2}' )
#        _remote_size=$(( _remote_size / _div ))
#        [[ $_remote_size -gt $_local_size ]]
#        StopIfError "Not enough disk space available on ${host}:${path} ($_remote_size < $_local_size)"
#        ;;
#    (rsync)
#        # TODO: how can we calculate the free size on remote system via rsync protocol??
#        :
#        ;;
#esac

