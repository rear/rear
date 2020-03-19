# 100_check_nfs_version.sh

# save the output of mount
mount | grep nfs > "$TMP_DIR/nfs.mount.info"

# make sure we have the nfs related kernel on-board
for module in $(lsmod|grep nfs|awk '{print $1}') ; do
    MODULES+=( $module )
done

# add any nfs related user to the rescue environment
# rpcuser  : default
# rpc      : used in RHEL7.x
# _rpc     : used in Debian 10
CLONE_USERS+=( rpcuser rpc _rpc )

# copy nfs related configuration files
COPY_AS_IS+=( /etc/nfsmount.conf /etc/sysconfig/nfs )

# create the required nfs related directories found under /var/lib/nfs
# in $ROOTFS_DIR
for src in $(find /var/lib/nfs -type d) ; do
    mkdir -p $v ${ROOTFS_DIR}${src} >&2
done

# verify is we require more nfsv4 related daemons
if grep -q nfs4 "$TMP_DIR/nfs.mount.info" ; then
    COPY_AS_IS+=( /etc/idmapd.conf )
    PROGS+=( nfsidmap nfsdcltrack nfsstat rpc.mountd rpc.idmapd )
    COPY_AS_IS+=( "/lib64/libnfsidmap/*" )

    if grep -q "sys=krb" "$TMP_DIR/nfs.mount.info" ; then
        # Kerberos used with nfsv4
        COPY_AS_IS+=( "/etc/request-key.d/*" /etc/request-key.conf /etc/gss /etc/gssproxy )
        PROGS+=( rpc.gssd request-key keyctl gssproxy gss_destroy_creds gss_clnt_send_err )
    fi
fi
