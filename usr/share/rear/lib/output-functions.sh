
# Functions required for output related stuff

# OUT: a valid usb device in /dev
function FindUsbDevices () {
    local d sysfspath device
    # we use the model to find USB devices
    for d in $( ls /sys/block/*/device/model ) ; do
        grep -q -i -E 'usb|FlashDisk' $d || continue
        # analyzing $d
        # /sys/block/sdb
        sysfspath="$( dirname $( dirname "$d" ) )"
        # bare device name
        # sdb
        device="$( basename "$sysfspath" )"
        # still need to check if device contains a partition?
        # if USB device has no partition table we skip this device
        if [ -f $sysfspath/${device}1/partition ] ; then
            # find a device node matching this device in /dev
            DeviceNameToNode "$device" || return 1
            Log "USB or disk device $device selected."
        else
            Log "USB or disk device /dev/$device does not contain a valid partition table - skip device."
        fi
    done
}

# Error out when files greater or equal ISO_FILE_SIZE_LIMIT should be included in the ISO (cf. default.conf)
# for files passed as arguments e.g: assert_ISO_FILE_SIZE_LIMIT file1 relative/path/file2 /absolute/path/file3 ...
# Normally there should be no error exit inside a function but a function should return non-zero exit code
# and leave it to its caller what to do depending on the callers environment. But this function is an exception.
# It is meant like the "assert" macro in C that outputs a message on stderr and then exits with abort().
# Furthermore it is less duplicated code to implement the error exit inside this function
# than to let this function return non-zero exit code and implement the error exit in each caller
# when the meaning of this function is to always exit for files greater or equal ISO_FILE_SIZE_LIMIT
# (for the reasoning why "always exit" for such files see default.conf).
# It errors out for the first file that is greater or equal ISO_FILE_SIZE_LIMIT and shows only this one to the user
# so if there are also other files greater or equal ISO_FILE_SIZE_LIMIT they are not shown. At least for now
# this should be sufficient because more than one file greater or equal ISO_FILE_SIZE_LIMIT is not expected
# and the "assert" meaning is that this error exit is there only as safeguard for exceptional cases.
function assert_ISO_FILE_SIZE_LIMIT () {
    # Skip when there is no usable ISO_FILE_SIZE_LIMIT set (in particular for ISO_FILE_SIZE_LIMIT=0):
    is_positive_integer $ISO_FILE_SIZE_LIMIT || return 0
    local file_for_iso file_for_iso_size
    for file_for_iso in "$@" ; do
        file_for_iso_size=$( stat -L -c '%s' $file_for_iso )
        # Continue "bona fide" with testing the next one if size could not be determined (assume the current one is OK):
        is_positive_integer $file_for_iso_size || continue
        # Continue testing the next one when this one is below the file size limit:
        test $file_for_iso_size -lt $ISO_FILE_SIZE_LIMIT && continue
        # Show only basename to avoid the meaningless ReaR-internal path where files for the ISO are (temporarily) located:
        Error "File for ISO $( basename $file_for_iso ) size $file_for_iso_size greater or equal ISO_FILE_SIZE_LIMIT=$ISO_FILE_SIZE_LIMIT"
    done
}
