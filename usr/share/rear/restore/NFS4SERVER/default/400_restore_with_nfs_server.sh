local nfs_connections duration start runtime \
    check_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_FINISHED_FILE" \
    abort_file="$TARGET_FS_ROOT/$NFS4SERVER_RESTORE_ABORT_FILE"

LogPrint "Mount the nfs share: 'mount -t nfs <ip>:/ <destination>' and$LF" \
    "restore all files to mounted destination."
LogPrint "Create the <destination>/$NFS4SERVER_RESTORE_FINISHED_FILE file$LF" \
    "when the restore is completed and umount the share."

rm -f "$check_file" "$abort_file" || Error "Couldn't delete restore finished file $check_file or abort file $abort_file"

LogPrint "Waiting until $check_file was created and there is no$LF" \
    "active connection on the NFS port 2049."

(( start = SECONDS ))
nfs_connections=1
ProgressStart "Restoring data"
while [ ! -f "$check_file" ] || [ "$nfs_connections" -gt 0 ]; do
    if [ -f "$abort_file" ]; then
        ProgressError
        Error "Restore aborted by abort file $abort_file. Reason given:$LF$(< "$abort_file"))"
    fi
    sleep "$PROGRESS_WAIT_SECONDS"
    (( duration = SECONDS - start ))
    printf -v runtime "%02d:%02d" $(( duration/60 )) $(( duration % 60 ))
    ProgressInfo "Waiting for $runtime minutes, total used storage space: $(total_target_fs_used_disk_space)"
    nfs_connections=$(ss -tanpH state established "( sport = 2049 )" | wc -l)
done
ProgressStop
(( duration = SECONDS - start ))
printf -v runtime "%02d:%02d" $(( duration/60 )) $(( duration % 60 ))
LogPrint "Restored $(total_target_fs_used_disk_space) in $runtime minutes."

rm -f "$check_file" || Error "Couldn't delete restore finished file $check_file"
