# The file mbr.bin is only added since syslinux 3.08
# The extlinux -i option is only added since syslinux 3.20

[[ -s "$SYSLINUX_DIR/mbr.bin" ]]
StopIfError "Could not find 'mbr.bin' in $SYSLINUX_DIR. Syslinux version 3.08 or newer is required, 4.x prefered !"
