#
# describe the device sizes of the physical devices.
#
while read device junk ; do
	mkdir -p ${TMP_DIR}$device
	sfdisk -s $device >${TMP_DIR}$device/size
	
done <$TMP_DIR/physical_devices
