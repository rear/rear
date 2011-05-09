# we assume that REAL_USB_DEVICE and RAW_USB_DEVICE are both set from the script
# in prep/USB/Linux-i386/35_check_usb_disk.sh

[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ] || Error "BUG BUG BUG RAW_USB_DEVICE and REAL_USB_DEVICE should be already set"

# ATM we support only extlinux as boot loader
extlinux -i "${BUILD_DIR}/usbfs/$USB_BOOT_PREFIX" 1>&2 || Error "Problem with extlinux -i ${BUILD_DIR}/usbfs/$USB_BOOT_PREFIX"

if [ "$REAL_USB_DEVICE" != "$RAW_USB_DEVICE" ] ; then
	# Write the USB boot sector if the filesystem is not the entire disk
	LogPrint "Writing MBR to $RAW_USB_DEVICE"
	dd if=$(dirname $ISO_ISOLINUX_BIN)/mbr.bin of=$RAW_USB_DEVICE bs=440 count=1 || Error "Problem with writing the mbr.bin to $RAW_USB_DEVICE"
else
	Log "Not writing MBR to $RAW_USB_DEVICE"
fi

# Need to flush the buffer for the USB boot sector.
# FIXME: limit this to the USB device
sync; sync
