#
# describe the device sizes of the physical devices.
#

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return
fi

while read device junk ; do
	# device is something like /dev/sda or /dev/cciss/c0d0
	mkdir -p $TMP_DIR$device
	StopIfError "Could not mkdir '$TMP_DIR$device'"

	sfdisk -d $device | grep -E "(unit:|${device}.*:)" >$TMP_DIR$device/sfdisk.partitions
	[ $PIPESTATUS -eq 0 ]
	StopIfError "Could not store the partition table for '$device'"

	sfdisk -g $device > $TMP_DIR$device/sfdisk.geometry
	StopIfError "Could not store geometry for '$device'"

	sfdisk -s $device > $TMP_DIR$device/size
	StopIfError "Could not store size for '$device'"

	FindDrivers $device >$TMP_DIR/$device/drivers
	StopIfError "Could not determine the required drivers for '$device'"
	# NOTE: The result can be empty if we simply don't know!

done <$TMP_DIR/physical_devices
