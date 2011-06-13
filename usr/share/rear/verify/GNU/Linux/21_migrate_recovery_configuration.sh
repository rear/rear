# patch the $VAR_DIR/recovery data to match changed disk configurations

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return
fi

mkdir -p $TMP_DIR/mappings
read_and_strip_file /etc/rear/mappings/disk_devices > $TMP_DIR/mappings/disk_devices

# skip if disk devices have not changed
if [ ! -s $TMP_DIR/mappings/disk_devices ]; then
    return
fi

# which files to patch
PATCH_FILES=( $(find $VAR_DIR/recovery -type f ) )

# Build SED script
DISK_DEVICE_MAPPINGS_SED_SCRIPT="";
while read old_device new_device size ; do
	# I try to cover the following scenarios:
	# old_device = /dev/sda, new_device = /dev/cciss/c0d0
	# old_device = /dev/sda, new_device = /dev/hda
	# old_device = /dev/cciss/c0d0, new_device = /dev/sda
	# (and of course two lines exchanging two devices)

	# first replace the main device
	DISK_DEVICE_MAPPINGS_SED_SCRIPT="$DISK_DEVICE_MAPPINGS_SED_SCRIPT;/${old_device//\//\\/}\([^p0-9]\+\|$\)/s#${old_device}#$new_device#g;tSEDMNTID"
	#											 ^^^^^^^^^^^
	#											    |
	#									either the old_device is followed NOT by [p0-9] or 
	#									it is followed by the end of the line
	#						                               ^^^^^^^
	#										  |
	#										is makes sure that we match only the main device
	#										and not a subdevice. Sadly the addess in sed must be
	#										specified in /../ so that we need to escape the / in
	#										the device name :-(
	#																^^^^^^^^^
	#														    		    /
	#							the ;t make sed process the next line instead of the next patterns on the same line
	#							the effect ist that each substitution will happen only once and thus
	#							we can support cyclic substitutions like exchanging sda and hda :-)


	# for the dependant devices we need to take care of the p between main device and partition numbers
	# modify the devices accordingly
	
        # move TO device with p suffix
        case "$new_device" in
                *rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
                        new_device="${new_device}p" # append p between main device and partitions

                        ;;
        esac
        # move FROM device with p suffix
        # this makes sure that when replacing c0d0 -> sda we actually replace c0d0p -> sda
        case "$old_device" in
                *rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
                        old_device="${old_device}p" # append p between main device and partitions
                        ;;
        esac

	# replace the dependant devices, they must have a partition number
	DISK_DEVICE_MAPPINGS_SED_SCRIPT="$DISK_DEVICE_MAPPINGS_SED_SCRIPT;/${old_device//\//\\/}[0-9]\+/s#${old_device}#$new_device#g;tSEDMNTID"

done < $TMP_DIR/mappings/disk_devices

Log "DISK_DEVICE_MAPPINGS_SED_SCRIPT: $DISK_DEVICE_MAPPINGS_SED_SCRIPT"


DISK_DEVICE_MAPPINGS_SED_SCRIPT="$DISK_DEVICE_MAPPINGS_SED_SCRIPT;: SEDMNTID;"


# step 1 - edit data in the files
sed -i -e "$DISK_DEVICE_MAPPINGS_SED_SCRIPT" "${PATCH_FILES[@]}"
LogPrintIfError "WARNING! There was an error patching the recovery configuration files!"


# We're adding our rules BEFORE the existing sed-script without ";t" to allow double-replacements in 
# /boot/grub/menu.lst. When replacing "by-id"-Strings cycling replacements aren't a real problem.
while read mountpoint real_device device_id filesystem ; do
        DISK_DEVICE_MAPPINGS_SED_SCRIPT="$DISK_DEVICE_MAPPINGS_SED_SCRIPT;s#${device_id}#$real_device#g"
done < <(grep -v /dev/mapper $VAR_DIR/recovery/mountpoint_device)

# step 1 - edit data in the files
sed -i -e "$DISK_DEVICE_MAPPINGS_SED_SCRIPT" "${PATCH_FILES[@]}"
LogPrintIfError "WARNING! There was an error patching the recovery configuration files!"

# step 2 - rename the device directories
# rename the directories that contain the device information
# we first move all source directories away and build it freshly up to
# handle cyclic changes gracefully (e.g. exchanging hda and sda)
mkdir -p $TMP_DIR/new_devices
while read old_device new_device size ; do
	# do the main devices first
	mkdir -p $TMP_DIR/new_devices/$(dirname $new_device)
	StopIfError "Could not create '$TMP_DIR/new_devices/$(dirname $new_device)'" # could be /dev or /dev/cciss

	cp -rv $VAR_DIR/recovery/$old_device $TMP_DIR/new_devices/$new_device >&2
	StopIfError "Could not cp '$VAR_DIR/recovery/$old_device' '$TMP_DIR/new_devices/$new_device'" 
		# e.g. ../dev/sda -> ../dev/cciss/c0d0

	# for the dependant devices we might have to add something between the main device and the partitions,
	# e.g. /dev/cciss/c0d0 -> /dev/cciss/c0d0p1

	# move TO device with p suffix
	case "$new_device" in
		*rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
			new_device="${new_device}p" # append p between main device and partitions
			;;
	esac
	# move FROM device with p suffix
	# this makes sure that when replacing c0d0 -> sda we actually replace c0d0p -> sda
	case "$old_device" in
		*rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
			old_device="${old_device}p" # append p between main device and partitions
			;;
	esac
	# find dependant devices, e.g. /dev/sda1 or /dev/cciss/c0d0p1
	for old_dir in $(find $VAR_DIR/recovery -type d -printf "/%P\n" | grep $old_device) ; do
		# old_dir is like /dev/sda1, note the missing $VAR_DIR/recovery and the / at the beginning
		new_dir=${old_dir/$old_device/$new_device} # substitute new device, e.g. /dev/sda2 -> /dev/cciss/c0d0p2
								# here we make use of the added 'p' in the step before!
		# do only something if old and new dir differ!
		[ "$old_dir" != "$new_dir" ]
		StopIfError "Failed to migrate '$old_dir': Directory name unchanged after substitution"

		# now move the data
		mkdir -p $TMP_DIR/new_devices/$(dirname $new_dir)
		StopIfError "Could not create '$TMP_DIR/new_devices/$(dirname $new_dir)'"

		mv -v $VAR_DIR/recovery/$old_dir $TMP_DIR/new_devices/$new_dir >&2
		StopIfError "Could not mv '$VAR_DIR/recovery/$old_dir' '$TMP_DIR/new_devices/$new_dir'"
		# e.g. ../dev/sda2 -> ../dev/cciss/c0d0p2
	done

done < $TMP_DIR/mappings/disk_devices

cp -rv $TMP_DIR/new_devices/dev $VAR_DIR/recovery/ >&2
StopIfError "Could not copy updated device information"
