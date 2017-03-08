# Test for features in dd
# true if dd supports oflag= option
FEATURE_DD_OFLAG=

dd_version=$(get_version "dd --version")
if version_newer "$dd_version" 5.3.0; then
    FEATURE_DD_OFLAG="y"
fi

# we assume that REAL_USB_DEVICE and RAW_USB_DEVICE are both set from the script
# in prep/USB/Linux-i386/350_check_usb_disk.sh

[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ]
BugIfError "RAW_USB_DEVICE and REAL_USB_DEVICE should be already set"

usb_syslinux_version=$(get_usb_syslinux_version)
syslinux_version=$(get_syslinux_version)

if [[ "$usb_syslinux_version" ]] && version_newer "$usb_syslinux_version" "$syslinux_version"; then
    Log "No need to update syslinux on USB media (version $usb_syslinux_version)."
    return
fi

# Make the USB bootable
usb_filesystem=$(grep -E "^($USB_DEVICE|$REAL_USB_DEVICE)\\s" /proc/mounts | cut -d' ' -f3 | tail -1)
case "$usb_filesystem" in
	(ext?)
		if [[ "$FEATURE_SYSLINUX_EXTLINUX_INSTALL" ]]; then
			extlinux -i "${BUILD_DIR}/outputfs/$SYSLINUX_PREFIX"
		else
			extlinux "${BUILD_DIR}/outputfs/$SYSLINUX_PREFIX"
		fi
		StopIfError "Problem with extlinux -i ${BUILD_DIR}/outputfs/$SYSLINUX_PREFIX"
		;;
	(ntfs|vfat)
		Error "Filesystem '$usb_filesystem' will not be supported."
		;;
	("")
		# This should never happen
		BugError "Filesystem for device '$REAL_USB_DEVICE' could not be found"
		;;
	(*)
		Error "Filesystem '$usb_filesystem' is not (yet) supported by syslinux."
		;;
esac

if [ "$REAL_USB_DEVICE" != "$RAW_USB_DEVICE" ] ; then
	# Write the USB boot sector if the filesystem is not the entire disk
	LogPrint "Writing MBR of type $USB_DEVICE_PARTED_LABEL to $RAW_USB_DEVICE"
	if [[ "$FEATURE_DD_OFLAG" ]]; then
		dd if=$SYSLINUX_MBR_BIN of=$RAW_USB_DEVICE bs=440 count=1 oflag=sync
	else
		dd if=$SYSLINUX_MBR_BIN of=$RAW_USB_DEVICE bs=440 count=1
		sync
	fi
	StopIfError "Problem with writing the mbr.bin to '$RAW_USB_DEVICE'"
else
	Log "WARNING: Not writing MBR to '$RAW_USB_DEVICE'"
fi
