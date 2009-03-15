# mount_filesystems.sh
# here we will mount all local filesystems as listed in mountpoint_device

while read mountpoint device mountby filesystem junk ; do
	mkdir -p "/mnt/local$mountpoint" || \
		Error "Could not create mountpoint '/mnt/local$mountpoint'"
	mount "$device"  "/mnt/local$mountpoint" -t "$filesystem"  || \
		Error "Mount failed of $device on /mnt/local$mountpoint type $filesystem"
done < "${VAR_DIR}/recovery/mountpoint_device"

mkdir -p /mnt/local/{proc,sys,dev,tmp} 
chmod 1777 /mnt/local/tmp
