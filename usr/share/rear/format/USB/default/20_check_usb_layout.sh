[[ "$DEVICE" ]]
StopIfError "USB device is not set."

[[ -b "$DEVICE" ]]
StopIfError "USB device '$DEVICE' is not a block device"

# Attempt to find the real USB device by trying its parent
# Return a proper short device name using udev
REAL_USB_DEVICE=$(readlink -f $DEVICE)

[[ "$REAL_USB_DEVICE" && -b "$REAL_USB_DEVICE" ]]
StopIfError "Unable to determine real USB device based on USB device '$DEVICE'."

# We cannot use the layout dependency code in the backup phase (yet)
#RAW_USB_DEVICE=$(find_disk $REAL_USB_DEVICE)

# Try to find the parent device (as we don't want to write MBR to a partition)
# the udevinfo query yields something like /devices/pci0000:00/0000:00:10.0/host2/target2:0:1/2:0:1:0/block/sdb/sdb1
# we want the "sdb" part of it.
TEMP_USB_DEVICE=$(basename $(dirname $(my_udevinfo -q path -n "$REAL_USB_DEVICE")))
if [[ "$TEMP_USB_DEVICE" == "block" ]]; then
    RAW_USB_DEVICE=$REAL_USB_DEVICE
elif [[ "$TEMP_USB_DEVICE" && -b "/dev/$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$TEMP_USB_DEVICE")"
elif [[ "$TEMP_USB_DEVICE" && -d "/sys/block/$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -p "$TEMP_USB_DEVICE")"
elif [[ -z "$TEMP_USB_DEVICE" ]]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$REAL_USB_DEVICE")"
else
    BugError "Unable to determine raw USB device for $REAL_USB_DEVICE"
fi

[[ "$RAW_USB_DEVICE" && -b "$RAW_USB_DEVICE" ]]
StopIfError "Unable to determine raw USB device for $REAL_USB_DEVICE"

answer=""

file_output=$(file -sbL "$REAL_USB_DEVICE")
ID_FS_TYPE=$(
    shopt -s nocasematch

    case "$file_output" in
        (*ext2\ filesystem*)
            echo "ext2";;
        (*ext3\ filesystem*)
            echo "ext3";;
        (*ext4\ filesystem*)
            echo "ext4";;
        (*btrfs\ filesystem*)
            echo "btrfs";;
        (*)
            echo "unknown";;
    esac
)

[[ "$ID_FS_TYPE" == btr* || "$ID_FS_TYPE" == ext* ]]
if (( $? != 0 )) && [[ -z "$YES" ]]; then
	echo "USB device $REAL_USB_DEVICE must be formatted with ext2/3/4 or btrfs file system"
	echo -n "Please type Yes to format $REAL_USB_DEVICE in ext3 format: "
	read answer
	[ "$answer" == "Yes" ]
	StopIfError "Abort USB format process by user"
elif [[ "$YES" ]]; then
	answer="Yes"
fi
