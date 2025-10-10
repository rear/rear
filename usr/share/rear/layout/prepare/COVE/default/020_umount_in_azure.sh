# Unmount /mnt, which is mounted by cloud-init in the Azure environment

if is_cove_in_azure; then
    LogPrint "Unmounting '/mnt' in Azure environments"
    umount_mountpoint /mnt
fi
