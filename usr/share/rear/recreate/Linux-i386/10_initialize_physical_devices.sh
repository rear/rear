#
# initialize physical devices for i386 and x86_64
#

LogPrint "Initializing physical devices"

while read device junk ; do

	# Wipe beginning of disk
	dd if=/dev/zero of=$device bs=1M count=10
	StopIfError "Could not wipe '$device'"

	# Restore MBR
	dd if=$VAR_DIR/recovery$device/mbr of=$device bs=446
	StopIfError "Could not restore MBR to '$device'"

	# Restore partition table
	if test -s $VAR_DIR/recovery$device/sfdisk.partitions ; then
		sfdisk --force $device <$VAR_DIR/recovery$device/sfdisk.partitions >&8
		StopIfError "Could not restore partition table to '$device'"
	else
		Log "Skipping partitioning '$device' (no sfdisk.partitions found)"
		sfdisk -R $device >&2
		StopIfError "Could not re-read '$device', probably it is busy."
	fi

done <$VAR_DIR/recovery/required_devices

# NOTE: We touch only the actually required devices, not all physical devices
