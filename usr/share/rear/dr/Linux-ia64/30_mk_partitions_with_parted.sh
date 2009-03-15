while read DEVICE
do
	# DEVICE = /dev/sda
	ParseDevice ${DEVICE}	# $Dev=sda
	ParseDisk ${Dev}	# ${dsk}=sda & ${_dsk}=sda
	test -d "$VAR_DIR/recovery${DEVICE}" || mkdir -p "$VAR_DIR/recovery${DEVICE}"

	parted -s ${DEVICE} print > "$VAR_DIR/recovery${DEVICE}/partitions" || \
		Error "Print partition list failed for device ${DEVICE}"
	# create_parted_script_for_recovery is a functions just sourced before calling this script
	# and may be OS version dependent (or parted version dependent)
	create_parted_script_for_recovery "$VAR_DIR/recovery${DEVICE}/parted" ${_dsk} "$VAR_DIR/recovery${DEVICE}/partitions" || \
		Error "Creating $VAR_DIR/recovery${DEVICE}/parted script failed"
	chmod +x "$VAR_DIR/recovery${DEVICE}/parted"
done < "$VAR_DIR/recovery/required_devices"
