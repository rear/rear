local check_file abort_file nfs_connections used_space

check_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_FINISHED_FILE"
abort_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_ABORT_FILE"

LogPrint "Mount the nfs share: 'mount -t nfs <ip>:/ <destination>' and restore all files to mounted destination."
LogPrint "Create the <destination>/$NFS4SERVER_RESTORE_FINISHED_FILE file when the restore is completed and umount the share."

rm -f "$check_file" "$abort_file" || Error "Couldn't delete restore finished file $check_file or abort file $abort_file"

LogPrint "Waiting until $check_file was created and there is no active connection on the NFS port 2049."

nfs_connections=1
while [ ! -f "$check_file" ] || [ "$nfs_connections" -gt 0 ]; do
    if [ -f "$abort_file" ]; then
        echo ""
        Error "Restore aborted by abort file $abort_file. Reason given:$LF$(< "$abort_file"))"
    fi
    used_space=$(
        df --total --local -h --exclude-type=tmpfs --exclude-type=devtmpfs | awk 'END{print $3}'
        ) && \
        ProgressInfo "      Used storage space: $used_space"
    sleep 5
    nfs_connections=$(ss -tanpH state established "( sport = 2049 )" | wc -l)
done

rm -f "$check_file" || Error "Couldn't delete restore finished file $check_file"
