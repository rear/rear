# as USB may be formatted with a file system format not in use on this system
# we better copy the kernel module, if modular, to out MODULES array so it
# is available in our recovery image
local usb_fs_type
usb_fs_type=$( fsck -N $USB_DEVICE | tail -1 | awk '{print $1}' | cut -d. -f2 )
[[ -z "$usb_fs_type" ]] && usb_fs_type="ext3"

MODULES+=( "$usb_fs_type" )
MODULES_LOAD+=( "$usb_fs_type" )
Log "Added USB Device $USB_DEVICE file system type $usb_fs_type to MODULES/MODULES_LOAD"
