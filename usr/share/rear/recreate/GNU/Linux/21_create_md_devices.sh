#
# Create MD devices

test -s $VAR_DIR/recovery/proc/mdstat || return # nothing to do here

LogPrint "Creating Software RAID devices"
# search for all md.devices files in our recovery data and work on them
while read file ; do
	# md device name
	device="/${file%%/md.devices}"

	# just in case, stop the md device
	mdadm --stop $device

	# check for required files
	for f in md.level; do
		[ -s $VAR_DIR/recovery$device/$f ]
		StopIfError "Required MD config file '$VAR_DIR/recovery$device/$f' is missing or empty"

		declare MD_OPTION_${f##md.}="$( cat $VAR_DIR/recovery$device/$f )"
		StopIfError "Could not read '$VAR_DIR/recovery$device/$f'"
	done

	# read in remaining MD options
	# this should set stuff like MD_OPTION_UUID or MD_OPTION_num_devices
	if test -s $VAR_DIR/recovery$device/md.options ; then
		. $VAR_DIR/recovery$device/md.options
	fi

	# Check that we have some devices
	[ -s $VAR_DIR/recovery$device/md.devices ]
	StopIfError "The '$VAR_DIR/recovery$device/md.devices' file is empty !"

	# RAID devices
	DEVICES=( $(cat $VAR_DIR/recovery$device/md.devices) )
	StopIfError "Could not read '$VAR_DIR/recovery$device/md.devices' !"

	# test number of RAID devices if we have this information from md.options
	if test "$MD_OPTION_num_devices" ; then
		[ "$MD_OPTION_num_devices" -eq "${#DEVICES[@]}" ]
		StopIfError "Number of RAID devices for '$device' differs between md.num_devices ($MD_OPTION_num_devices) and md.devices (${#DEVICES[@]}) !"
	else
		# num_devices was not given, calculate it from the DEVICES array
		MD_OPTION_num_devices=${#DEVICES[@]}
	fi

	# test RAID level
	case "$MD_OPTION_level" in
		linear|stripe|mirror|multipath|md|faulty|0|1|4|5|6|10|raid0|raid1|raid4|raid5|raid6|raid10)
		:
		;;
		*)
		Error "Invalid RAID level '$MD_OPTION_level' specified for '$device'"
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
		) --verbose >&2 <<<y ; then
		:
	else
		# now the old style
		Log "Fancy mdadm failed, trying plain old style"
		mdadm --create $device --level=$MD_OPTION_level --raid-devices=$MD_OPTION_num_devices --force "${DEVICES[@]}" <<<y
		StopIfError "Could not create the MD device '$device'"
	fi

done < <(
	cd $VAR_DIR/recovery
	find . -name md.devices -printf "%P\n"
	)
