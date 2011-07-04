# functions required for the actual disaster recovery

#
# Guess a block device from a given block device with partitions
# This is just a collection of special workarounds for buggy drivers
#
# IN: devicename like /dev/cciss/c0d0p1
# OUT: devicename like /dev/cciss/c0d0
#
GuessPhysicalDevice () {
	case "$1" in
	/dev/cciss?c*)
		echo "${1%p*}"
		;;
	*)
		Log "Could not guess physical device for '$1'"
		return 1
		;;
	esac
}

#
# Find a device node in /dev for a given device in /sys/block
#
# IN: devicename from /sys/block (e.g. sda, sda1, cciss!c0d0 ...)
# OUT: block device in /dev with full path (e.g. /dev/sda, /dev/sda1, /dev/cciss/c0d0 ...)
#
DeviceNameToNode () {
	# since the old style cciss/c0d0 is slowly beeing migrated to cciss!c0d0 (the internal
	# kernel representation), we try to replace ! by / and check that, too.
	device="/dev/$1"
	device2="${device//\!//}"

	if test -b $device ; then
		echo $device
	elif test -b $device2 ; then
		echo $device2
	else
		Log "BUG BUG BUG ! I could not determine a device node for '$1', I tried '$device' and '$device2'"
		return 1
	fi

	# TODO: Try to find the device by looking at the MAJOR:MINOR numbers as a last alternative
}

#
# Print a list of physical devices (in the format of their /dev/ device node entries) available
# by querying the block devices in /sys/block
#
# skips removable devices (floppy, cdrom ...)
#
# OUT: list of device nodes in /dev
#
FindPhysicalDevices () {
	# all phsical devices have device link in /sys/block/*.
	# Logical devices (DM, MD, RAM, ...) don't have it
	#
	# we use the device link to find out the physical devices from the logical ones
	for d in $(ls -d /sys/block/*/device) ; do
		case "$d" in
			.) continue ;;
		esac
		# This should always be a directory, I want to know if it is not.
		if ! test -d $d ; then
			Log "BUG BUG BUG Please report to the authors that '$d' is NOT a directory on your system !"
			return 1
		fi

		sysfspath="$(dirname "$d")"		# /block/sys/sda
		# bare device name
		device="$(basename "$sysfspath")"	# sda

		# device size according to sysfs, usually in 512bytes units
		if ! test -s $sysfspath/size ; then
			Log "BUG BUG BUG Please report to the authors that '$sysfspath/size' is empty for '$d' on your system !"
			return 1
		fi
		sysfssize="$(cat $sysfspath/size)"
		# Skip removable devices (floppy, CD, ...), but only if their size is less than
		# SYSFS_REMOVABLE_DEVICE_SIZE in GB. hot-plug SCSI discs also appear to be removable
		# but are probably larger than 15GB while DVDs tend to stay smaller
		#
		# TODO: With the now available BD and HD-DVD discs, this assumption is of course
		# plainly wrong, but I didn't manage to come up with something better.
		#
		test $(cat $sysfspath/removable) -eq 1 -a \
		$((sysfssize/2/1024/1024)) -le ${SYSFS_REMOVABLE_DEVICE_SIZE:=15} && {
			Log "Skipping small removable device '$device' [Size: $((sysfssize/2/1024/1024))GB]. Adjust SYSFS_REMOVABLE_DEVICE_SIZE [$SYSFS_REMOVABLE_DEVICE_SIZE] to prevent this."
			continue
		}

		# find a device node matching this device in /dev
		DeviceNameToNode "$device" || return 1

	done
}

