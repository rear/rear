# The file mbr.bin is only added since syslinux 3.08
# The extlinux -i option is only added since syslinux 3.20

local mbr_image_file

# Choose right MBR image file for right partition table type (issue #1153)
case "$USB_DEVICE_PARTED_LABEL" in
    "msdos")
        mbr_image_file="mbr.bin"
    ;;
    "gpt")
        mbr_image_file="gptmbr.bin"
    ;;
    *)
        Error "USB_DEVICE_PARTED_LABEL is incorrectly set, please check your settings."
    ;;
esac

SYSLINUX_MBR_BIN=$(find_syslinux_file $mbr_image_file)

[[ -s "$SYSLINUX_MBR_BIN" ]]
StopIfError "Could not find file '$mbr_image_file'. Syslinux version 3.08 or newer is required, 4.x prefered!"
