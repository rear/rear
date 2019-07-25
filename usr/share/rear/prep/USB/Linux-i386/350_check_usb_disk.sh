
test "$USB_DEVICE" || Error "USB device (USB_DEVICE) is not set."

# Attempt to find the real USB device by trying its parent.
# Return a proper short device name using udev:
REAL_USB_DEVICE=$( readlink -f $USB_DEVICE )

test -b "$REAL_USB_DEVICE" || Error "USB device '$USB_DEVICE' is not a block device"

# Check if the ReaR USB device is not accidentally mounted on other than $BUILD_DIR location:
if res=( $( grep -v $BUILD_DIR /proc/mounts | grep "^$REAL_USB_DEVICE" ) ) ; then
    Error "USB device '$REAL_USB_DEVICE' is already mounted on '${res[1]}'"
fi

# Try to find the parent device (as we don't want to write MBR to a partition)
# the udevinfo query yields something like
# /devices/pci0000:00/0000:00:10.0/host2/target2:0:1/2:0:1:0/block/sdb/sdb1
# we want the "sdb" part of it.
TEMP_USB_DEVICE=$(basename $(dirname $(my_udevinfo -q path -n "$REAL_USB_DEVICE")))
if [ "$TEMP_USB_DEVICE" -a -b "/dev/$TEMP_USB_DEVICE" ]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$TEMP_USB_DEVICE")"
elif [ "$TEMP_USB_DEVICE" -a -d "/sys/block/$TEMP_USB_DEVICE" ]; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -p "$TEMP_USB_DEVICE")"

# If we're passed a raw device, ala /dev/sdb, TEMP_USB_DEVICE will be set to "block"
# and RAW_USB_DEVICE won't be set.  "block" is not useful.  TEMP_USB_DEVICE will not be
# set if udev doesn't know anything about the device we were passed. So, if we've 
# gotten here and either are not set, let's just assert what we know from udev
# about the device.
elif [ -z "$TEMP_USB_DEVICE" ] || [ -z "$RAW_USB_DEVICE" ] ; then
    RAW_USB_DEVICE="/dev/$(my_udevinfo -q name -n "$REAL_USB_DEVICE")"
else
    BugError "Unable to determine raw USB device for $REAL_USB_DEVICE"
fi

test "$RAW_USB_DEVICE" -a -b "$RAW_USB_DEVICE" || Error "Unable to determine raw USB device for $REAL_USB_DEVICE"

