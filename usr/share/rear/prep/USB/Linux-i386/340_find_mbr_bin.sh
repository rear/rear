# The file mbr.bin is only added since syslinux 3.08
# The extlinux -i option is only added since syslinux 3.20

# Find out what the actual USB disk partition table type is
# of the USB disk that is the parent device of the USB data partition
# that is the value of the USB_DEVICE variable.
# For example
#   BACKUP_URL=usb:///dev/disk/by-label/REAR-000
# leads to
#   USB_DEVICE=/dev/disk/by-label/REAR-000
# which is a symbolic link e.g. to /dev/sdb3 (on a hybrid UEFI and BIOS dual boot USB disk)
# so its parent device /dev/sdb is where we need to inspect the partition table type.
# See the code of the write_protection_ids() function in lib/write-protect-functions.sh
# how to get the parent device.
# See the output of
#   # find usr/sbin/rear usr/share/rear -type f | xargs grep 'Partition Table'
# for code how to autodetect the partition table type via 'parted ... print'.
# In summary it goes like this example:
#   # USB_DEVICE=/dev/disk/by-label/REAR-000
#   # usb_disk="$( lsblk -inpo PKNAME "$USB_DEVICE" 2>/dev/null | awk NF | head -n1 )"
#   # echo $usb_disk
#   /dev/sdb
#   # usb_disk_label=$( parted -s $usb_disk print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " " )
#   # echo $usb_disk_label
#   gpt
# see https://github.com/rear/rear/pull/2829/files#r906006257

local usb_disk usb_disk_label mbr_image_file

usb_disk="$( lsblk -inpo PKNAME "$USB_DEVICE" 2>/dev/null | awk NF | head -n1 )"
# Older Linux distributions do not contain lsblk (e.g. SLES10)
# and older lsblk versions do not support the output column PKNAME
# e.g. lsblk in util-linux 2.19.1 in SLES11 supports NAME and KNAME but not PKNAME
# see the code of the write_protection_ids() function in lib/write-protect-functions.sh
# so we use USB_DEVICE_PARTED_LABEL as fallback when the 'lsblk' automatism does not work
# and also when 'parted' does not show "msdos" or "gpt":
if test -b "$usb_disk" ; then
    usb_disk_label=$( parted -s $usb_disk print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " " )
    if test "$usb_disk_label" = "msdos" || test "$usb_disk_label" = "gpt" ; then
        # Tell the user when his specified USB_DEVICE_PARTED_LABEL does not match the actual USB disk partition type:
        if test "$USB_DEVICE_PARTED_LABEL" && test "$usb_disk_label" != "$USB_DEVICE_PARTED_LABEL" ; then
            LogPrintError "Overwriting USB_DEVICE_PARTED_LABEL with '$usb_disk_label' to match USB disk partition type"
        fi
        USB_DEVICE_PARTED_LABEL="$usb_disk_label"
    fi
fi

# Choose the right MBR image file for the partition table type (issue #1153)
case "$USB_DEVICE_PARTED_LABEL" in
    (msdos)
        mbr_image_file="mbr.bin"
        ;;
    (gpt)
        mbr_image_file="gptmbr.bin"
        ;;
    (*)
        Error "Unsupported USB disk partition table type '$USB_DEVICE_PARTED_LABEL' (neither 'msdos' nor 'gpt')"
        ;;
esac

SYSLINUX_MBR_BIN=$( find_syslinux_file $mbr_image_file )

test -s "$SYSLINUX_MBR_BIN" || Error "Could not find SYSLINUX MBR image file '$mbr_image_file' (at least SYSLINUX 3.08 is required, 4.x preferred)"
