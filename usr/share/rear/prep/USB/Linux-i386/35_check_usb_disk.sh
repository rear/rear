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

parted "$RAW_USB_DEVICE" print 2>/dev/null | grep primary | grep -qE '(ntfs|fat)'
[[ $? -eq 0 ]] && Error "USB device $RAW_USB_DEVICE must be formatted with ext3/4 file system"
