# Make the USB bootable
syslinux -s ${USB_DEVICE}
# Write the USB boot sector
dd if=$(dirname ${ISO_ISOLINUX_BIN})/mbr.bin of=${USB_DEVNODE}
# Need to flush the buffer for the USB boot sector.
sync; sync
