# Make the USB bootable
syslinux --stupid ${USB_DEVICE}
ProgressStopIfError $? "Problem with syslinux --stupid ${USB_DEVICE}"
ProgressStep
# Write the USB boot sector
dd if=$(dirname ${ISO_ISOLINUX_BIN})/mbr.bin of=`echo ${USB_DEVICE} | sed -e 's/[0-9]$//'`
ProgressStopIfError $? "Problem with writing the mbr.bin to `echo ${USB_DEVICE} | sed -e 's/[0-9]$//'`"
ProgressStep
# Need to flush the buffer for the USB boot sector.
sync; sync
