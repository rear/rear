# Attempt to find the real USB device by trying its parent
# Return a proper short device name using udev
TEMP_USB_DEVICE=$(dirname $(my_udevinfo -q path -n "$USB_DEVICE"))
if [[ -d "/sys/$TEMP_USB_DEVICE" && "$TEMP_USB_DEVICE" =~ "^/block/" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -p "$TEMP_USB_DEVICE")"
else
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$USB_DEVICE")"
fi

# Make the USB bootable
syslinux  $USB_DEVICE
ProgressStopIfError $? "Problem with syslinux  $USB_DEVICE"
ProgressStep

# Write the USB boot sector
dd if=$(dirname $ISO_ISOLINUX_BIN)/mbr.bin of=$RAW_USB_DEVICE
ProgressStopIfError $? "Problem with writing the mbr.bin to $RAW_USB_DEVICE"
ProgressStep

# Need to flush the buffer for the USB boot sector.
sync; sync
