# mdadm_cfg_saving script
#
#
# 2007-01-04	GSS	Adapted to use /sys

# silently skip the script if mdstat shows no raid configured
# we check for 'blocks' and not for 'raid' to also cover the md type devices
grep -q blocks /proc/mdstat || return

mkdir -p ${VAR_DIR}/recovery/proc
cat /proc/mdstat > "${VAR_DIR}/recovery/proc/mdstat" ||\
	Error "Saving /proc/mdstat failed: $?"

# now we have to determine the RAID devices for each raid
mdadm --detail --scan --config=partitions | while read ARRAY mddev options ; do
	# sanity check, skip all lines that are NOT an array
	test "$ARRAY" = ARRAY || continue
	
	# sanity check, the block device must exist
	test -b $mddev || Error "The MD block device '$mddev' does not exist / is not a block device"

	# exclude MD devices here
	if IsInArray "$mddev" "${EXCLUDE_MD[@]}" ; then
		Log "Skipping excluded array '$mddev'"
		continue
	fi
	

	mkdir -p $VAR_DIR/recovery/$mddev
	
	mddevname="$(basename "$mddev")" # /dev/md0 -> md0
	DEVICES=()

	read -a md < <(grep "$mddevname" /proc/mdstat )
	# $md looks now like this:
	# md1 : active raid1 sdb2[0] sdc2[1]

	# store the RAID level
	echo "${md[3]}" >$VAR_DIR/recovery/$mddev/md.level
	# walk through $md from index 4 and get the devices (this WILL fail on missing devices !)
	c=4
	while test "${md[c]}" ; do
		devname="${md[c]}"
		let c++
		devname="${devname%%[*}" # strip off [x] from devname
		DEVICES=( "${DEVICES[@]}" "$(DeviceNameToNode "$devname")" ) # sda -> /dev/sda
	done
	
	
	# store the raid devices
	echo "${DEVICES[@]}" >$VAR_DIR/recovery/$mddev/md.devices
	
	# the raid devices are also the dependancy of this MD device
	# TODO: Check for further dependancies like RAID-on-LVM ...
	echo "${DEVICES[@]}" | tr ' ' "\n" >$VAR_DIR/recovery/$mddev/depends

	# parse options, they look like level=1 num-devices=2 UUID=...
	# sadly, different Linux versions/distros sport different levels of information here...
	# therefore we can only save what we get and hope for the best
	for opt in $options ; do
		key="${opt%%=*}"
		val="${opt##*=}"
		# I don't remember what for we need the variable defined here
		# So I take it out and wait who cries...
		### Schlomo removed ### declare MD_OPTION_${key//-/_}="$val"
		echo "MD_OPTION_${key//-/_}='$val'"
	done >>$VAR_DIR/recovery/$mddev/md.options

done
# if the mdadm before the | above fails then we will know it here
test $PIPESTATUS -gt 0 && Error "mdadm scan failed: $PIPESTATUS"

