# 400_restore_with_nfs_server.sh

FILE=$TARGET_FS_ROOT/rear_finished.txt

NFS_PORT=2049

Print "Mount the nfs share: 'mount -t nfs -o nfsvers=4 <ip>:/ <destination>' and restore all files to mounted destination."
Print "Create the $FILE file when the restore is completed and umount the share."

rm -rf $FILE

Print "Wait until $FILE was created and there is no connection on the NFS-Port $NFS_PORT."

#  or look at /var/lib/nfs/rmtab
nfs_connections=$(ss -tanpH state established "( sport = $NFS_PORT )" | wc -l)

while [ ! -f "$FILE" ] || [ "$nfs_connections" -gt 0 ]; do
    sleep 5
    nfs_connections=$(ss -tanpH state established "( sport = $NFS_PORT )" | wc -l)
done

rm -rf $FILE

unset $FILE
unset $NFS_PORT
