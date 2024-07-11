# 300_start_nfs_server.sh

# same options works for mountd
local nfsd_opts=(--no-udp --no-nfs-version 3 -V 4.2)
local cpu_cores
cpu_cores=$(nproc) || Error "Could not determine CPU details via nproc"
# 4 threads per cpu core
local nfs_threads=$(( $cpu_cores * 4 ))
# 8 are the standard and should be the minimum
if (( nfs_threads < 8 )); then nfs_threads=8; fi

# clear /etc/exports if the user rerun the restore with other options
> /etc/exports

# add all mountpoints to /etc/exports
while read mountpoint junk ; do
    local options=("${NFS4SERVER_EXPORT_OPTS[@]}")
    if [[ $mountpoint == "/" ]]; then
        options+=("fsid=0")
    else
        options+=(nohide)
    fi
    local nfs_options=$(IFS=',' ; echo "${options[*]}")
    local nfs_trust_options=""
    for trust in "${NFS4SERVER_TRUSTED_CLIENTS[@]}"; do
        nfs_trust_options+="$trust($nfs_options) "
    done

    echo "${TARGET_FS_ROOT}${mountpoint} $nfs_trust_options" >> /etc/exports
done < "${VAR_DIR}/recovery/mountpoint_device"
Debug "$(cat /etc/exports)"

exportfs $v -ra || Error "exportfs failed!"

rpc.nfsd --debug "$nfs_threads" "${nfsd_opts[@]}" || Error "rpc.nfsd failed!"
Debug "nfsd started with $nfs_threads threads."

if [ -z "$(pidof rpc.mountd)" ]; then
    rpc.mountd --debug all "${nfsd_opts[@]}" || Error "rpc.mountd failed!"
fi

LogPrint "NFS-Server started successfully."
