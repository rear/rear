# mount_filesystems.sh
# here we will mount all local filesystems as listed in mountpoint_device

while read mountpoint device mountby filesystem options junk; do
	mkdir -p "/mnt/local$mountpoint"
	StopIfError "Could not create mountpoint '/mnt/local$mountpoint'"

	options="$options,noatime"
	options="${options//defaults/}" # remove 'defaults' from options as this is used only in fstab
	options="${options//,,/,}" # replace ,, with , (might be result of defaults removal)
	options="${options#,}" # remove leading , in case we had no options

	mount -o "$options" "$device"  "/mnt/local$mountpoint" -t "$filesystem"
	StopIfError "Mount failed of $device on /mnt/local$mountpoint type $filesystem options $options"
done < "${VAR_DIR}/recovery/mountpoint_device"

# In case they are missing we add the standard directories
mkdir -p /mnt/local/{proc,sys,dev,tmp}
chmod 1777 /mnt/local/tmp
