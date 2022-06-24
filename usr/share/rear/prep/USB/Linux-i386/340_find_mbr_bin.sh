# The file mbr.bin is only added since syslinux 3.08
# The extlinux -i option is only added since syslinux 3.20

local mbr_image_file

# Choose right MBR image file for right partition table type (issue #1153)
case "$USB_DEVICE_PARTED_LABEL" in
    (msdos)
        mbr_image_file="mbr.bin"
        ;;
    (gpt)
        mbr_image_file="gptmbr.bin"
        ;;
    (*)
        Error "USB_DEVICE_PARTED_LABEL='$USB_DEVICE_PARTED_LABEL' (neither 'msdos' nor 'gpt')"
        ;;
esac

SYSLINUX_MBR_BIN=$( find_syslinux_file $mbr_image_file )

test -s "$SYSLINUX_MBR_BIN" || Error "Could not find SYSLINUX MBR image file '$mbr_image_file' (at least SYSLINUX 3.08 is required, 4.x preferred)"
