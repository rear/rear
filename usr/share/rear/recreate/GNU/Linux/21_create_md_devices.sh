#
# Create MD devices

test -s $VAR_DIR/recovery/proc/mdstat || return # nothing to do here

ProgressStart "Creating Software RAID devices"
# search for all md.devices files in our recovery data and work on them
while read file ; do
	# md device name
	device="/${file%%/md.devices}"
	
	# just in case, stop the md device
	mdadm --stop $device
	ProgressStep

	# check for required files
	for f in md.level; do
		test -s $VAR_DIR/recovery$device/$f
		ProgressStopIfError $? "Required MD config file '$VAR_DIR/recovery$device/$f' is missing or empty"
		declare MD_OPTION_${f##md.}="$( cat $VAR_DIR/recovery$device/$f )"
		ProgressStopIfError $? "Could not read '$VAR_DIR/recovery$device/$f'"
	done

	# read in remaining MD options
	# this should set stuff like MD_OPTION_UUID or MD_OPTION_num_devices
	if test -s $VAR_DIR/recovery$device/md.options ; then
		. $VAR_DIR/recovery$device/md.options
	fi

	# Check that we have some devices
	test -s $VAR_DIR/recovery$device/md.devices
	ProgressStopIfError $? "The '$VAR_DIR/recovery$device/md.devices' file is empty !"
	ProgressStep

	# RAID devices
	DEVICES=( $(cat $VAR_DIR/recovery$device/md.devices) )
	ProgressStopIfError $? "Could not read '$VAR_DIR/recovery$device/md.devices' !"
	ProgressStep

	# test number of RAID devices if we have this information from md.options
	if test "$MD_OPTION_num_devices" ; then
		test "$MD_OPTION_num_devices" -eq "${#DEVICES[@]}"
		ProgressStopIfError $? "Number of RAID devices for '$device' differs between md.num_devices ($MD_OPTION_num_devices) and md.devices (${#DEVICES[@]}) !"
		ProgressStep
	else 
		# num_devices was not given, calculate it from the DEVICES array
		MD_OPTION_num_devices=${#DEVICES[@]}
	fi

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
	# first try the fancy way and if it fails, then try the old-style way
	if mdadm --create $device --level=$MD_OPTION_level --raid-devices=$MD_OPTION_num_devices --force "${DEVICES[@]}" \
		$(
		for var in ${!MD_OPTION*}; do
			# skipt level and num_devices as we used it already
			case $var in 
				(*level|*num_devices) continue;;
			esac
			# convert MD_OPTION_UUID into uuid
			optname=$(sed -e 's/MD_OPTION_//' -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/' <<<$var)
			echo "--$optname ${!var} "
		done
		) --verbose 1>&2 <<<y ; then
			ProgressStep
	else
		# now the old style
		Log "Fancy mdadm failed, trying plain old style"
		mdadm --create $device --level=$MD_OPTION_level --raid-devices=$MD_OPTION_num_devices --force "${DEVICES[@]}" <<<y
		ProgressStopIfError $? "Could not create the MD device '$device'"
		ProgressStep
	fi

done < <(
	cd $VAR_DIR/recovery
	find . -name md.devices -printf "%P\n" 
	)

ProgressStop
