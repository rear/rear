#
# determine the actually required physical devices
#
# This is in case that there are some unused (or excluded) devices installed.
#
# Changes:
# 2007-11-06	GSS	Added major 254 to exclude list as it seems to
#			be the device-mapper device on newer 2.6 kernels
# 2009-03-02	GD	Added 147 (DRDB cluster) in exclude list
# 2009-11-21	GSS	Added -L to stat call
# 2011-01-12	GD	Added 252 (vda virtual disks) to skipping list

REQUIRED_DEVICES=()

while read device junk ; do
	# device=/dev/sdc2 or /dev/mapper/vg1-lv1 or /dev/md0 ...
	# since device could be a symlink we use -L to query the real device
	eval $(stat -L -c 'dev="$((0x%t)):$((0x%T))"' $device )
	# dev=MAJOR:MINOR in DECIMAL, e.g. dev=8:32

	# Here we have to filter out well-known virtual devices, mostly dm and md
	case "$dev" in
		147:*|251:*|252:*|253:*|254:*|9:*)
			Log "Skipping dependancy tracking for DRDB/device mapper/mdp/softraid device '$device' [$dev]"
			continue
			;;
	esac
	
	# Now we should have only real physical devices. If not, then THIS script has a bug and the above
	# list needs to be extended
			
	# On some systems there seem to be several devices with the same MAJOR:MINOR (maybe some kind of RAID ?)
	# so that we have to be careful not to assume the the grep below will always return exactly one match
	sysfspath=( $(grep -rl "^$dev\$" /sys/block/*/dev /sys/block/*/*/dev) )

	# If there is no match or too many matches, just bail out
	[ ${#sysfspath[@]} -eq 1 ]
	BugIfError "There is more than one device in /sysfs for '$dev':
${sysfspath[@]}
Please file a bug with complete info about your system, e.g. (fake) RAID, LVM, MD, ..."

	# sysfspath=/sys/block/sdc/sdc2/dev
	#
	# we wakk up the sysfspath till we find a directory that contains a symlink to device
	# At this level we reached the actual physical device
	#
	checkpath="$(dirname "$sysfspath")" # /sys/block/sdc/sdc2
	while test "$checkpath" != /sys -a ! -L "$checkpath"/device ; do
		checkpath="$(dirname "$checkpath")"
	done

	#
	#
	# NOTE: Some block drivers are buggy or not yet adapted to the new 2.6 kernel layout and
	# do not provide the device link we rely on
	#
	# So far I have seen the cciss driver on SLES10 behave like that.
	#
	# We can only guess the correct result here :-(
	#
	# Check the result, which of the 2 exit conditions above exited the while loop
	if test "$checkpath" = /sys ; then
		physical_device="$(GuessPhysicalDevice "$device")"
		StopIfError "Could not guess physical device for '$device' [$dev] in '$sysfspath'.
This is probably a bug in your kernel or in $PRODUCT, 
so please file a bug report about this."
		if test -b "$physical_device" ; then
		       	REQUIRED_DEVICES=( "${REQUIRED_DEVICES[@]}" "$physical_device" )
			Log "WARNING ! I guessed that '$physical_device' is the physical device for '$device' [$dev] in '$sysfspath' but I might be wrong about that !"
		else
			Error "I could not find the physical device for '$device' [$dev] in '$sysfspath'.
This might be a bug in $PRODUCT, so please file a bug report about this."
		fi
	else
	# checkpath=/sys/block/sdc 

	# The only remaining option is now that $checkpath contains a device link
		REQUIRED_DEVICES=( "${REQUIRED_DEVICES[@]}" "$(DeviceNameToNode "$(basename "$checkpath")")" )
	fi
	
done < <(
	find $VAR_DIR/recovery -name depends -exec cat '{}' \; | sort -u
	)
	
for d in "${REQUIRED_DEVICES[@]}" ; do 
	echo "$d"
done | sort -u >$VAR_DIR/recovery/required_devices

LogPrint "Physical devices that will be recovered:" $(cat $VAR_DIR/recovery/required_devices)
