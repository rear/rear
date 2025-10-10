# Unmount /mnt, which is mounted by cloud-init in the Azure environment

if is_cove_in_azure; then
    umount_mountpoint /mnt
fi
