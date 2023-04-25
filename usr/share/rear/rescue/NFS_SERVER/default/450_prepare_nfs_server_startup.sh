# 450_prepare_nfs_server_startup.sh
# make sure nfs-server startup scripts gets included in the rescue image

# mkdir -p $ROOTFS_DIR/etc/systemd/system

# for service in ${NFS_SERVICES[@]}; do
#     out=$(systemctl show -p FragmentPath $service)
#     service_path=${out#*FragmentPath=}

#     cp $service_path $ROOTFS_DIR/etc/systemd/system/
# done

# chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-nfs-server.sh
# Log "Created the NFS-Server start-up script (90-nfs-server.sh) for ReaR"
