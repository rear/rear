# find swap partitions and files

while read device type size junk ; do
	# look only at swap devices/files that start from /
	test "$device" = Filename && continue # header
	test "${device:0:1}" = / || {
		LogPrint "Ignoring relative swap device/file '$device'"
		continue
	}

	DEPENDS=""
	case "$type" in
		partition)
			: # no special stuff required, just remember the dependancy
			DEPENDS="$device"
		;;
		file)
			# make sure that the swapfile is on a mountpoint that is not excluded
			# otherwise we should skip it entirely

			# find the mountpoint by using df (LANG=C is crucial here !)
			df=( $(df "$device") )

			# the mountpoint is ${df[12]}
			missing=yes
			while read mountpoint junk ; do
				if test "$mountpoint" = "${df[12]}" ; then
					missing=""
					break
				fi
			done <${VAR_DIR}/recovery/mountpoint_device
			# if the mountpoint for this swapfile is "missing", then we skip it
			if test "$missing" ; then
				Log "Skipping swapfile '$device' because it is not on an included mountpoint"
				continue
			fi

			# store the size to recreate the swap file
			filesize=$(stat -c "%s" "$device")
			megs=$((filesize/1024/1024))
			echo "$device $megs" >>"${VAR_DIR}/recovery/swapfiles"
		;;
		*)
			LogPrint "Ignoring unknown swap type '$type'"
			continue
		;;
	esac
	# for swap partitions and files alike: Create swap_vol_id
	mkdir -p "${VAR_DIR}/recovery${device}"
	rear_vol_id $device >${VAR_DIR}/recovery${device}/swap_vol_id
	StopIfError "Could not read swap space info from '$device'. The rear_vol_id wrapper (using vol_id or blkid) has a problem reading it."
	test "$DEPENDS" && echo "$DEPENDS" >${VAR_DIR}/recovery${device}/depends
done </proc/swaps
