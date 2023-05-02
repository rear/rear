# 300_start_nfs_server.sh

# same options works for mountd
local nfsd_opts="--no-udp --no-nfs-version 3"
local cpu_cores=$(grep ^cpu\\scores /proc/cpuinfo | uniq | cut -d ':' -f 2 | xargs)
# 4 threads per cpu core
local nfs_threads=$(( $cpu_cores * 4 ))
# 8 are the standard and should be the minumun
if [[ "$nfs_threads" -lt 8 ]]; then nfs_threads=8; fi

# add all mountpoints to /etc/exports
while read mountpoint junk ; do
    options="$NFS_SERVER_EXPORT_OPTS"
    if [[ $mountpoint == "/" ]]; then
        options+=",fsid=0"
    else
        options+=",nohide"
    fi

    if ! grep -q "${TARGET_FS_ROOT}${mountpoint}" /etc/exports; then
        echo "${TARGET_FS_ROOT}${mountpoint} $NFS_SERVER_TRUSTED($options)" >> /etc/exports
    fi
done < "${VAR_DIR}/recovery/mountpoint_device"
Debug "$(cat /etc/exports)"

exportfs $v -ra || Error "exportfs failed!"

rpc.nfsd --debug $nfs_threads $nfsd_opts || Error "rpc.nfsd failed!"
Debug "nfsd startet with $nfs_threads threads."

if [ -z "$(pidof rpc.mountd)" ]; then
    rpc.mountd --debug all $nfsd_opts || Error "rpc.mountd failed!"
fi

Print "NFS-Server started successfully."
