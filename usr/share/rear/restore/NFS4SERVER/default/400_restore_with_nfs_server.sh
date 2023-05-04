local check_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_FINISHED_FILE" nfs_connections used_space

LogPrint "Mount the nfs share: 'mount -t nfs <ip>:/ <destination>' and restore all files to mounted destination."
LogPrint "Create the <destination>/$NFS4SERVER_RESTORE_FINISHED_FILE file when the restore is completed and umount the share."

rm -f "$check_file" || Error "Couldn't delete restore finished file $check_file"

LogPrint "Waiting until $check_file was created and there is no connection on the NFS-Port 2049."

nfs_connections=1
while [ ! -f "$check_file" ] || [ "$nfs_connections" -gt 0 ]; do
    used_space=$(
        df --total --local -h --exclude-type=tmpfs --exclude-type=devtmpfs | awk 'END{print $3}'
        ) && \
        ProgressInfo "      Used storage space: $used_space"
    sleep 5
    nfs_connections=$(ss -tanpH state established "( sport = 2049 )" | wc -l)
done

rm -f "$check_file" || Error "Couldn't delete restore finished file $check_file"
