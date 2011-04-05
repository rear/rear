# Attempt to find the real USB device by trying its parent
# Return a proper short device name using udev
REAL_USB_DEVICE=$(readlink -f $USB_DEVICE)

[[ "$REAL_USB_DEVICE" && -b "$REAL_USB_DEVICE" ]]
ProgressStopIfError $? "Unable to determine real USB device based on $USB_DEVICE"

# We cannot use the layout dependency code in the backup phase (yet)
#RAW_USB_DEVICE=$(find_disk $REAL_USB_DEVICE)

# Try to find the parent device (as we don't want to write MBR to a partition)
TEMP_USB_DEVICE=$(basename $(dirname $(my_udevinfo -q path -n "$REAL_USB_DEVICE")))
if [[ "$TEMP_USB_DEVICE" && -b "/dev/$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$TEMP_USB_DEVICE")"
elif [[ "$TEMP_USB_DEVICE" && -d "/sys/block/$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -p "$TEMP_USB_DEVICE")"
elif [[ -z "$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$REAL_USB_DEVICE")"
else
    BugError "Unable to determine raw USB device for $REAL_USB_DEVICE"
fi

[[ "$RAW_USB_DEVICE" && -b "$RAW_USB_DEVICE" ]]
ProgressStopIfError $? "Unable to determine raw USB device for $REAL_USB_DEVICE"

# Make the USB bootable
usb_filesystem="$(grep -P "^$REAL_USB_DEVICE\\s" /proc/mounts | cut -d' ' -f3 | tail -1)"
case "$usb_filesystem" in
    (ext?)
        extlinux -i "${BUILD_DIR}/netfs/boot/syslinux"
        ProgressStopIfError $? "Problem with extlinux -i ${BUILD_DIR}/netfs/boot/syslinux"
        if [[ -z "$FEATURE_SYSLINUX_GENERIC_CFG" ]]; then
            # add symlink for extlinux.conf
            ln -sf syslinux.cfg "${BUILD_DIR}/netfs/boot/syslinux/extlinux.conf"
            ProgressStopIfError $? "Could not create symlinks for extlinux.conf"
        fi
        ;;
    (ntfs|vfat)
        Error "Filesystem $usb_filesystem will not be supported."
        ;;
    ("")
        # This should never happen
        BugError "Filesystem for device $REAL_USB_DEVICE could not be found"
        ;;
    (*)
        Error "Filesystem $usb_filesystem is not (yet) supported by syslinux."
        ;;
esac
ProgressStep

if [ "$REAL_USB_DEVICE" != "$RAW_USB_DEVICE" ] ; then
	# Write the USB boot sector
	LogPrint "Writing MBR to $RAW_USB_DEVICE"
	dd if=$(dirname $ISO_ISOLINUX_BIN)/mbr.bin of=$RAW_USB_DEVICE bs=440 count=1
	ProgressStopIfError $? "Problem with writing the mbr.bin to $RAW_USB_DEVICE"
	ProgressStep
else
	Log "Not writing MBR to $RAW_USB_DEVICE"
fi

# Need to flush the buffer for the USB boot sector.
sync; sync
