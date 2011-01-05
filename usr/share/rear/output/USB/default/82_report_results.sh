# report to user what we did
#USB_SIZE=( $( du -shc "${USB_FILES[@]}" | tail -n 1 ) )

#LogPrint "Please put the following files ($USB_SIZE) onto your prepared USB stick ${USB_FILES[@]}"

# cp -a will sometimes report errors.
# Unable to change owner / mode of files on VFAT.
# So just use plain cp here, not cp -a.
cp -v "${USB_FILES[@]}" "$BUILD_DIR/netfs" 1>&8
ProgressStopIfError $? "Could not copy files to usb location"
Log "Copied ${USB_FILES[@]} to $BUILD_DIR/netfs"

# Add to RESULT_FILES for emailing it
RESULT_FILES=( "${RESULT_FILES[@]}" "${USB_FILES[@]}" )
