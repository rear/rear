# Compare required physical devices in the original system and now.
# We compare two things: Existance and size.

# for each required physical device that does not exist or that is too small
# we ask the user to specify a device from $available_devices

# NOTE: This algorithm is the first version and not suitable for all possible
# situations. I see the following problems:
# - if only some devices are missing, this code silently assumes that the matching
#   devices are to be used. Since they are not removed from $available_devices
#   this might lead to a double assignment of the same (new) physical device: Once 
#   because it matched an original physical device and once through a manual mapping
# - The support for CCISS style devices is there but I never tested it

# NOTE: Better would be to first check the presence of the original device layout and
# then, if there was any difference, force the user to map ALL devices, also those that
# accidentially matched the original devices.

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return
fi

# create temporary list of available devices and their sizes
# contains lines like "/dev/sda 4194304"
available_devices="$(
	while read device junk ; do
		echo "$device $(cat $TMP_DIR$device/size)"
	done <$TMP_DIR/physical_devices
)"

# check if a valid mapping files exists and if the mapped devices are big enough
DISK_MAPPING_COUNT=0

mkdir -p $TMP_DIR/mappings
test -f $CONFIG_DIR/mappings/disk_devices && read_and_strip_file $CONFIG_DIR/mappings/disk_devices > $TMP_DIR/mappings/disk_devices

if test -s $TMP_DIR/mappings/disk_devices ; then
	while read original_device; do
		new_device=$(grep "^$original_device" $CONFIG_DIR/mappings/disk_devices | awk '{ print $2 }')
		if test $new_device ; then
			if [ $(cat $VAR_DIR/recovery$original_device/size) -le $(sfdisk -s $new_device) ] ; then
				let DISK_MAPPING_COUNT++
				LogPrint "Valid disk mapping found for $original_device"
			else
				LogPrint "Warning: A disk mapping file has been found. But the size of $new_device is too small for the contents of $original_device. Rear will continue with the manual mapping procedure."
			fi
		fi
	done <$VAR_DIR/recovery/required_devices
fi

test $DISK_MAPPING_COUNT -ge $(wc -l < $VAR_DIR/recovery/required_devices) && return 0 # skip if valid mapping is available


# fallback to manual mapping
for device in $(cat $VAR_DIR/recovery/required_devices) ; do
	# device is /dev/sda or /dev/cciss/c0d0

	# size is set in 11_describe_device_properties.sh
	original_size="$(cat $VAR_DIR/recovery$device/size)"
	size="$(cat ${TMP_DIR}$device/size 2>&8 )"
	test "$size" || size=0 # set size to sane value if unknown

	
	# Each original physical device must exist
	if grep -q "$device" $TMP_DIR/physical_devices && test "$size" -ge "$original_size" ; then
		: noop, all is fine
	elif test "$available_devices" ; then
		# try to find another physical device to work with, only possible if there are still
		# some unclaimed devices available

		Log "available_devices='$available_devices'"

		# build list of possible candidates to replace the device
		# list contains entries of "/dev/sda 4 GB"
		DEVICE_LIST=()
		while read checkdevice checksize ; do
			if test "$checksize" -ge "$original_size" ; then
				DEVICE_LIST=( "${DEVICE_LIST[@]}" "$checkdevice $((checksize/1024/1024)) GB" )
			fi
		done < <(echo "$available_devices") # note: vim on F11 had a problem with syntax highlighting and <<< here!
			
		# display unit in GB	
		let display_original_size=original_size/1024/1024 display_size=size/1024/1024
		
		LogPrint "
WARNING! The original device $device [$display_original_size GB] is not available
or too small$(test $size -gt 0 && echo " [$display_size GB]")."

		[ "$DEVICE_LIST" ]
		StopIfError "Required physical device '$device' could not be found and no suitable alternative available!"

		# we have alternatives, offer them
		LogPrint "Please select another device to replace '$device' from this list:"
		PS3="
Enter a number to choose: "
		select choice in "${DEVICE_LIST[@]}" "Cancel selection and abort recovery" ; do
			n=( $REPLY ) # trim blanks from reply
			let n-- # because bash arrays count from 0
			if test "$n" == "${#DEVICE_LIST[@]}" -o "$n" -lt 0 -o "$n" -ge "${#DEVICE_LIST[@]}"; then
				Error "Recovery aborted by user."
			fi
			break
		done 2>&1 # to get the prompt, otherwise it would go to the logfile

		# write out mapping file
		mkdir -p /etc/rear/mappings
		echo "$device $choice" >>/etc/rear/mappings/disk_devices
		# remember that choice contains something like "/dev/sda 4 GB" :-)

		chosen_device=( $choice ) # get first word
		# remove this choice from the list of $available_devices
		available_devices="$(grep -v $chosen_device <<<"$available_devices")"
	else
		Error "No more devices available. This script is not able to
change the amount or size of the disk devices, only replace one device
with another device of at least the same size. Please add more disks to
this system and try again or contribute/sponsor a better script that can
also change the amount and size of the target disk devices.
"
	fi
done 


