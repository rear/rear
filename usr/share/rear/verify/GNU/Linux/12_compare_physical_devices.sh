# Compare required physical devices in the original system and now.
# We compare two things: Existance and size.

while read device junk ; do
	# Each original physical device must exist
	grep -q "$device" $TMP_DIR/physical_devices || \
		Error "Required physical device '$device' could not be found !"
	mkdir -p $TMP_DIR$device || \
		Error "Could not create '$TMP_DIR$device'"
	sfdisk -s $device >$TMP_DIR$device/size 2>/dev/null || \
		Error "Could not read size of '$device'"

	test -s "$VAR_DIR/recovery$device/size" || \
       		BugError "'$VAR_DIR/recovery$device/size' is missing."
	test -s "${TMP_DIR}$device/size" || \
		BugError "'${TMP_DIR}$device/size' is missing."

	original_size="$(cat $VAR_DIR/recovery$device/size)"
	size="$(cat ${TMP_DIR}$device/size)"	
	test "$size" -ge "$original_size" || \
		Error "The physical device '$device' is smaller than the original:
Original size: $original_size
Current size: $size

NOTE: Recovering on smaller hard disks is a planned feature. You are
cordially invited to participate in the development and contribute or
sponsor the development of this feature. This feature will also allow
$PRODUCT to be used as a deployment tool."

done <$VAR_DIR/recovery/required_devices
