# report to user what we did
USB_SIZE=( $( du -shc "${USB_FILES[@]}" | tail -n 1 ) )

# LogPrint "Please put the following files ($USB_SIZE) onto your prepared USB stick ${USB_FILES[@]}"

# cp -a will sometimes report errors.
# Unable to change owner / mode of files on VFAT.
# So just use plain cp here, not cp -a.
cp "${USB_FILES[@]}" "$BUILD_DIR/netfs"
Log "Copied ${USB_FILES[@]} to $BUILD_DIR/netfs"

# Make the USB bootable
syslinux -s ${USB_DEVICE}
# Write the USB boot sector
dd if=/usr/lib/syslinux/mbr.bin of=${USB_DEVNODE}
# Need to flush the buffer for the USB boot sector.
sync; sync

# Add to RESULT_FILES for emailing it
RESULT_FILES=( "${RESULT_FILES[@]}" "${USB_FILES[@]}" )
