# we assume that REAL_USB_DEVICE and RAW_USB_DEVICE are both set from the script
# in prep/USB/Linux-i386/35_check_usb_disk.sh

[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ]
BugIfError "RAW_USB_DEVICE and REAL_USB_DEVICE should be already set"

usb_syslinux_version=$(get_usb_syslinux_version)
syslinux_version=$(get_syslinux_version)

if [[ "$usb_syslinux_version" ]] && version_newer "$usb_syslinux_version" "$syslinux_version"; then
    Log "No need to update syslinux on USB media (version $usb_syslinux_version)."
    return
fi

# Make the USB bootable
usb_filesystem=$(grep -P "^$REAL_USB_DEVICE\\s" /proc/mounts | cut -d' ' -f3 | tail -1)
case "$usb_filesystem" in
	(ext?)
		if [[ "$FEATURE_SYSLINUX_EXTLINUX_INSTALL" ]]; then
			extlinux -i "${BUILD_DIR}/usbfs/$SYSLINUX_PREFIX"
		else
			extlinux "${BUILD_DIR}/usbfs/$SYSLINUX_PREFIX"
		fi
		StopIfError "Problem with extlinux -i ${BUILD_DIR}/usbfs/$SYSLINUX_PREFIX"
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
	LogPrint "Writing MBR to $RAW_USB_DEVICE"
	dd if=$(dirname $ISO_ISOLINUX_BIN)/mbr.bin of=$RAW_USB_DEVICE bs=440 count=1
	StopIfError "Problem with writing the mbr.bin to '$RAW_USB_DEVICE'"
else
	Log "WARNING: Not writing MBR to '$RAW_USB_DEVICE'"
fi

# Need to flush the buffer for the USB boot sector.
# FIXME: limit this to the USB device
sync; sync
