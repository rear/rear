# The file mbr.bin is only added since syslinux 3.08
# The extlinux -i option is only added since syslinux 3.20

SYSLINUX_MBR_BIN=$(find_syslinux_file mbr.bin)
[[ -s "$SYSLINUX_MBR_BIN" ]]
StopIfError "Could not find 'mbr.bin' in $(dirname $SYSLINUX_MBR_BIN). Syslinux version 3.08 or newer is required, 4.x prefered !"
