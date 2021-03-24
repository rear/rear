
test "$DEVICE" || Error "Disk device is not set"

test -b "$DEVICE" || Error "Device $DEVICE is not a block device"

# Attempt to find the real USB device by trying its parent
# Return a proper short device name using udev
REAL_USB_DEVICE=$(readlink -f $DEVICE)

test "$REAL_USB_DEVICE" -a -b "$REAL_USB_DEVICE" || Error "Unable to determine real disk device for $DEVICE"

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

test "$RAW_USB_DEVICE" -a -b "$RAW_USB_DEVICE" || Error "Unable to determine raw disk device for $REAL_USB_DEVICE"

USB_format_answer=""

test "ext3" = "$USB_DEVICE_FILESYSTEM" -o "ext4" = "$USB_DEVICE_FILESYSTEM" || USB_DEVICE_FILESYSTEM="ext3"

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
    LogUserOutput "disk device $REAL_USB_DEVICE is not formatted with ext2/3/4 or btrfs filesystem"
    # When USER_INPUT_USB_DEVICE_CONFIRM_FORMAT has any 'true' value be liberal in what you accept and assume exactly 'Yes' was actually meant:
    is_true "$USER_INPUT_USB_DEVICE_CONFIRM_FORMAT" && USER_INPUT_USB_DEVICE_CONFIRM_FORMAT="Yes"
    USB_format_answer="$( UserInput -I USB_DEVICE_CONFIRM_FORMAT -p "Type exactly 'Yes' to format $REAL_USB_DEVICE with $USB_DEVICE_FILESYSTEM filesystem" -D 'No' )"
    test "Yes" = "$USB_format_answer" || Error "Aborted disk format by user (user input '$USB_format_answer' is not 'Yes')"
elif [[ "$YES" ]]; then
    USB_format_answer="Yes"
fi
