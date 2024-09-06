
test "$FORMAT_DEVICE" || Error "USB or disk device is not set"

test -b "$FORMAT_DEVICE" || Error "Device $FORMAT_DEVICE is not a block device"

# Attempt to find the real USB device by trying its parent
# Return a proper short device name using udev
REAL_USB_DEVICE=$( readlink -f $FORMAT_DEVICE )

test -b "$REAL_USB_DEVICE" || Error "Real device $REAL_USB_DEVICE of $FORMAT_DEVICE is no block device"

# Try to find the parent device (as we don't want to write MBR to a partition)
# the udevinfo query yields something like /devices/pci0000:00/0000:00:10.0/host2/target2:0:1/2:0:1:0/block/sdb/sdb1
# we want the "sdb" part of it.
TEMP_USB_DEVICE=$( basename $( dirname $( my_udevinfo -q path -n "$REAL_USB_DEVICE" ) ) )
if [[ "$TEMP_USB_DEVICE" == "block" ]] ; then
    RAW_USB_DEVICE=$REAL_USB_DEVICE
elif [[ "$TEMP_USB_DEVICE" && -b "/dev/$TEMP_USB_DEVICE" ]] ; then
    RAW_USB_DEVICE="/dev/$( my_udevinfo -q name -n "$TEMP_USB_DEVICE" )"
elif [[ "$TEMP_USB_DEVICE" && -d "/sys/block/$TEMP_USB_DEVICE" ]] ; then
    RAW_USB_DEVICE="/dev/$( my_udevinfo -q name -p "$TEMP_USB_DEVICE" )"
elif [[ -z "$TEMP_USB_DEVICE" ]] ; then
    RAW_USB_DEVICE="/dev/$( my_udevinfo -q name -n "$REAL_USB_DEVICE" )"
elif [[ -n "$( lsblk -r -o NAME,KNAME,TYPE,PKNAME | grep "$(basename $REAL_USB_DEVICE)" | grep part )" ]]; then
    RAW_USB_DEVICE="/dev/$( lsblk -r -o NAME,KNAME,TYPE,PKNAME | grep "$(basename $REAL_USB_DEVICE)" | grep part | awk '{print $4}' | uniq )"
elif [[ -n "$( lsblk -r -o NAME,KNAME,TYPE,PKNAME | grep "$(basename $REAL_USB_DEVICE)" | grep disk )" ]]; then
    RAW_USB_DEVICE="$REAL_USB_DEVICE"
else
    BugError "Unable to determine raw device for $REAL_USB_DEVICE"
fi

test -b "$RAW_USB_DEVICE" || Error "Raw device $RAW_USB_DEVICE of $REAL_USB_DEVICE is no block device"

# USB_FORMAT_ANSWER is also used in format/USB/default/300_format_usb_disk.sh
USB_FORMAT_ANSWER=""

case "$USB_DEVICE_FILESYSTEM" in
    ("")
        USB_DEVICE_FILESYSTEM="ext3";;
    (ext3|ext4)
        :;;
    (*)
        Error "Invalid USB_DEVICE_FILESYSTEM value '$USB_DEVICE_FILESYSTEM'. Must be 'ext3' or 'ext4'.";;
esac

local file_output=$( file -sbL "$REAL_USB_DEVICE" )
# ID_FS_TYPE is also used in format/USB/default/350_label_usb_disk.sh
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
if (( $? != 0 )) && [[ -z "$FORMAT_YES" ]] ; then
    LogUserOutput "USB or disk device $REAL_USB_DEVICE is not formatted with ext2/3/4 or btrfs filesystem"
    LogUserOutput "Formatting $REAL_USB_DEVICE will remove all currently existing data on that whole device"
    # When USER_INPUT_USB_DEVICE_CONFIRM_FORMAT has any 'true' value be liberal in what you accept and assume exactly 'Yes' was actually meant:
    is_true "$USER_INPUT_USB_DEVICE_CONFIRM_FORMAT" && USER_INPUT_USB_DEVICE_CONFIRM_FORMAT="Yes"
    USB_FORMAT_ANSWER="$( UserInput -I USB_DEVICE_CONFIRM_FORMAT -p "Type exactly 'Yes' to format $REAL_USB_DEVICE with $USB_DEVICE_FILESYSTEM filesystem" -D 'No' )"
    test "Yes" = "$USB_FORMAT_ANSWER" || Error "Aborted disk format by user (user input '$USB_FORMAT_ANSWER' is not 'Yes')"
elif [[ "$FORMAT_YES" ]] ; then
    USB_FORMAT_ANSWER="Yes"
fi
