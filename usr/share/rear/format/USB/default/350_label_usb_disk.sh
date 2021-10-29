
# USB_FORMAT_ANSWER was set before by format/USB/default/200_check_usb_layout.sh
# FORMAT_FORCE may have been set by lib/format-workflow.sh
[[ "$USB_FORMAT_ANSWER" == "Yes" || "$FORMAT_FORCE" ]] || return 0

# USB_DATA_PARTITION_NUMBER was set before by format/USB/default/300_format_usb_disk.sh
local data_partition_device="$RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER"

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it:
for dummy in "once" ; do
    # TODO: I <jsmeix@suse.de> wonder what the reason is why here
    # a filesystem label USB_DEVICE_FILESYSTEM_LABEL is set via e2label or btrfs filesystem label
    # versus before in format/USB/default/300_format_usb_disk.sh where a so called
    # "volume label for the filesystem" (according to "man mkfs.ext[34]")
    # was already set via mkfs.$USB_DEVICE_FILESYSTEM -L "$USB_DEVICE_FILESYSTEM_LABEL"
    # is this duplicate here or are that different kind of labels?
    case "$ID_FS_TYPE" in
        (ext*)
            USB_LABEL="$( e2label $data_partition_device )"
            test "$USB_DEVICE_FILESYSTEM_LABEL" = "$USB_LABEL" && continue
            LogPrint "Setting filesystem label to '$USB_DEVICE_FILESYSTEM_LABEL'"
            if ! e2label $data_partition_device "$USB_DEVICE_FILESYSTEM_LABEL" ; then
                Error "Could not label $data_partition_device with '$USB_DEVICE_FILESYSTEM_LABEL'"
            fi
            USB_LABEL="$( e2label $data_partition_device )"
            ;;
        (btrfs)
            USB_LABEL="$( btrfs filesystem label $data_partition_device )"
            test "$USB_DEVICE_FILESYSTEM_LABEL" = "$USB_LABEL" && continue
            LogPrint "Setting btrfs filesystem label to '$USB_DEVICE_FILESYSTEM_LABEL'"
            if ! btrfs filesystem label $data_partition_device "$USB_DEVICE_FILESYSTEM_LABEL" ; then
                Error "Could not label $data_partition_device with '$USB_DEVICE_FILESYSTEM_LABEL'"
            fi
            USB_LABEL="$( btrfs filesystem label $data_partition_device )"
            ;;
        (*)
            # ID_FS_TYPE can be 'unknown', cf. format/USB/default/200_check_usb_layout.sh
            return
            ;;
    esac
done

# signal kernel to reread partition table to get /dev/disk/by-label
partprobe $RAW_USB_DEVICE
# Wait until udev has had the time to kick in
sleep 5

# Report the final result to the user:
LogPrint "Data partition $data_partition_device has filesystem label '$USB_LABEL'"

