while read device junk
do
	# device = /dev/sda
	#ParseDevice ${device}	# $Dev=sda
	#ParseDisk ${Dev}	# ${dsk}=sda & ${_dsk}=sda
	mkdir -p "$VAR_DIR/recovery${device}"

	parted -s ${device} print > "$VAR_DIR/recovery${device}/partitions" || \
		Error "Print partition list failed for device ${device}"
	# NOTE: create_parted_script_for_recovery is a functions just sourced before calling this script
	# and may be OS version dependent (or parted version dependent)
	create_parted_script_for_recovery "$VAR_DIR/recovery${device}/parted" ${device} "$VAR_DIR/recovery${device}/partitions" || \
		Error "Creating $VAR_DIR/recovery${device}/parted script failed"
	chmod +x "$VAR_DIR/recovery${device}/parted"
done < "$VAR_DIR/recovery/required_devices"
