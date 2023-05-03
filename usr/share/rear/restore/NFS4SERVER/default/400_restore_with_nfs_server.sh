# 400_restore_with_nfs_server.sh

local check_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_FINISHED_FILE"

LogPrint "Mount the nfs share: 'mount -t nfs <ip>:/ <destination>' and restore all files to mounted destination."
LogPrint "Create the $check_file file when the restore is completed and umount the share."

rm -f $check_file || Error "Couldn't delete restore finished file $check_file"

LogPrint "Wait until $check_file was created and there is no connection on the NFS-Port 2049."

# or look at /var/lib/nfs/rmtab
local nfs_connections=1
while [ ! -f "$check_file" ] || [ "$nfs_connections" -gt 0 ]; do
    local used_space
    used_space=$(df --total --local -h --exclude-type=tmpfs --exclude-type=devtmpf | tail -n 1 | awk '{print $3}') &&
        ProgressInfo "      Used storage space: $used_space"
    
    sleep 5
    nfs_connections=$(ss -tanpH state established "( sport = 2049 )" | wc -l)
done

rm -f $check_file || Error "Couldn't delete restore finished file $check_file"
