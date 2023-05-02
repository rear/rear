# 400_restore_with_nfs_server.sh

local check_file=$TARGET_FS_ROOT/$NFS_SERVER_RESTORE_FINISHED_FILE

Print "Mount the nfs share: 'mount -t nfs -o nfsvers=4 <ip>:/ <destination>' and restore all files to mounted destination."
Print "Create the $check_file file when the restore is completed and umount the share."

rm -rf $check_file

Print "Wait until $check_file was created and there is no connection on the NFS-Port 2049."

# or look at /var/lib/nfs/rmtab
nfs_connections=1
while [ ! -f "$check_file" ] || [ "$nfs_connections" -gt 0 ]; do
    sleep 5
    nfs_connections=$(ss -tanpH state established "( sport = 2049 )" | wc -l)
done

rm -rf $check_file
