#
# initialize physical devices for ppc
#

ProgressStart "Initializing physical devices"

while read device junk ; do
	
	# Wipe beginning of disk
	dd if=/dev/zero of=$device bs=1M count=10
		ProgressStopIfError $? "Could not wipe '$device'"
	ProgressStep
	
	# Restore partition table
	if test -s $VAR_DIR/recovery$device/sfdisk.partitions ; then
		sfdisk --force $device <$VAR_DIR/recovery$device/sfdisk.partitions 1>&8
			ProgressStopIfError $? "Could not restore partition table to '$device'"
	else
		Log "Skipping partitioning '$device' (no sfdisk.partitions found)"
		sfdisk -R $device 1>&2
		ProgressStopIfError $? "Could not re-read '$device', probably it is busy."
	fi

done <$VAR_DIR/recovery/required_devices

# NOTE: We touch only the actually required devices, not all physical devices

ProgressStop
