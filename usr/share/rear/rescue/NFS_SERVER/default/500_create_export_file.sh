# 500_prepare_nfs_server_startup.sh

cat >$ROOTFS_DIR/etc/exports <<-EOF
/mnt/local      $NFS_SERVER_TRUSTED(fsid=0,$NFS_SERVER_EXPORT_OPTS)
EOF