#
# Create MD devices

test -s $VAR_DIR/recovery/proc/mdstat || return # nothing to do here

ProgressStart "Creating Software RAID devices"
while read file ; do
	# md device name
	device="/${file%%/md.devices}"
	
	# just in case, stop the md device
	mdadm --stop $device
	ProgressStep

	# check for required files
	for f in md.level md.num_devices ; do
		test -s $VAR_DIR/recovery$device/$f
		ProgressStopIfError $? "Required MD config file '$VAR_DIR/recovery$device/$f' is missing or empty"
		declare MD_OPTION_${f##md.}="$( cat $VAR_DIR/recovery$device/$f )"
		ProgressStopIfError $? "Could not read '$VAR_DIR/recovery$device/$f'"
	done
	
	# Check that we have some devices
	test -s $VAR_DIR/recovery$device/md.devices
	ProgressStopIfError $? "The '$VAR_DIR/recovery$device/md.devices' file is empty !"
	ProgressStep

	# RAID devices
	DEVICES=( $(cat $VAR_DIR/recovery$device/md.devices) )
	ProgressStopIfError $? "Could not read '$VAR_DIR/recovery$device/md.devices' !"
	ProgressStep

	# test number of RAID devices
	test "$MD_OPTION_num_devices" -a "$MD_OPTION_num_devices" -eq "${#DEVICES[@]}"
	ProgressStopIfError $? "Number of RAID devices for '$device' differs between md.num_devices ($MD_OPTION_num_devices) and md.devices (${#DEVICES[@]}) !"
	ProgressStep

	# test RAID level
	case "$MD_OPTION_level" in
		linear|stripe|mirror|multipath|md|faulty|0|1|4|5|6|raid0|raid1|raid4|raid5|raid6)
		:
		;;
		*)
		ProgressStopIfError 1 "Invalid RAID level '$MD_OPTION_level' specified for '$device'"
		;;
	esac

	# Create the array
	mdadm --create $device --level=$MD_OPTION_level --raid-devices=$MD_OPTION_num_devices --force "${DEVICES[@]}" <<<y
	ProgressStopIfError $? "Could not create the MD device '$device'"
	ProgressStep

done < <(
	cd $VAR_DIR/recovery
	find . -name md.devices -printf "%P\n" 
	)

ProgressStop
