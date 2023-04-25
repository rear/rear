# 300_start_nfs_server.sh

# same options works for mountd
NFSD_OPTS="--no-udp --no-nfs-version 3" 

rpcbind -w || Error "rpcbind failed!"
Debug "$(rpcinfo)"

# for older nfs versions
if is_false $NFS_SERVER_V4_ONLY; then
    rpc.idmapd || Error "rpc.idmapd failed!"
    rpc.gssd -v || Error "rpc.gssd failed!"
    rpc.statd --no-syslog || Error "rpc.statd failed!"
    NFSD_OPTS=""
fi

# add all mountpoints to /etc/exports
while read mountpoint junk ; do
    options="$NFS_SERVER_EXPORT_OPTS,nohide"

    if [[ ! $mountpoint == "/" ]]; then
cat << EOF >> /etc/exports
${TARGET_FS_ROOT}${mountpoint} $NFS_SERVER_TRUSTED($options)
EOF
    fi

done < "${VAR_DIR}/recovery/mountpoint_device"

Debug "$(cat /etc/exports)"
exportfs -ra || Error "exportfs failed!"

rpc.nfsd --debug 8 $NFSD_OPTS || Error "rpc.nfsd failed!"
rpc.mountd --debug all $NFSD_OPTS || Error "rpc.mountd failed!"

# Check mountd is running with a valid pid
if [ -z "$(pidof rpc.mountd)" ]; then
    Error "NFS-Server startup failed!"
fi

Print "NFS-Server started successfully"

unset $NFSD_OPTS
