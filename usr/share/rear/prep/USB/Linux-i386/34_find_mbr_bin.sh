[[ -s "$SYSLINUX_DIR/mbr.bin" ]]
ProgressStopIfError $? "Could not find 'mbr.bin' in $SYSLINUX_DIR. Maybe syslinux version is too old ?"
