# describe all filesystems

while read mountpoint device mountby filesystem junk ; do
	mkdir -p $VAR_DIR/recovery$device
	vol_id $device >$VAR_DIR/recovery$device/fs_vol_id || \
		Error "Cannot determine filesystem info on '$device'
Your udev implementation (vol_id or udev_volume_id) does not recognize it."
	echo "$device" >$VAR_DIR/recovery$device/depends
done <$VAR_DIR/recovery/mountpoint_device
