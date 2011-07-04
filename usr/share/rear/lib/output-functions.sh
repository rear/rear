# functions required for output related stuff

#
# OUT: a valid usb device in /dev
#
FindUsbDevices () {
	# we use the model to find USB devices
	for d in $(ls /sys/block/*/device/model) ; do
		grep -q -i -E 'usb|FlashDisk' $d || continue
		#echo "**** Analyzing $d"

		sysfspath="$(dirname $(dirname "$d"))"		# /sys/block/sdb
		# bare device name
		device="$(basename "$sysfspath")"	# sdb

		# still need to check if device contains a partition?
		# if USB device has no partition table we skip this device
		if [ -f $sysfspath/${device}1/partition ]; then
			# find a device node matching this device in /dev
			DeviceNameToNode "$device" || return 1
			Log "USB device $device selected."
		else
			Log "USB device /dev/$device does not contain a valid partition table - skip device."
		fi

	done
}
