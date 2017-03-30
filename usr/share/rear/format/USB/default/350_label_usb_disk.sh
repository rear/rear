
# TODO: Setting rear_data_partition_number again here looks duplicate because
# it should have been already set in format/USB/default/300_format_usb_disk.sh
# that was run just before this script:
if is_true "$EFI" ; then
    # Partition 1 is the EFI system partition (vfat partition).
    # Partition 2 is the ReaR data partition:
    rear_data_partition_number=2
else
    rear_data_partition_number=1
fi

local rear_data_partition_device="$RAW_USB_DEVICE$rear_data_partition_number"

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it:
for dummy in "once" ; do
    # TODO: I <jsmeix@suse.de> wonder what the reason is why here
    # a filesystem label REAR-000 is set via e2label or btrfs filesystem label
    # versus before in format/USB/default/300_format_usb_disk.sh where a so called
    # "volume label for the filesystem" (according to "man mkfs.ext[34]")
    # was already set via mkfs.$USB_DEVICE_FILESYSTEM -L REAR-000
    # is this duplicate here or are that different kind of labels?
    case "$ID_FS_TYPE" in
        ext*)
            USB_LABEL="$( e2label $rear_data_partition_device )"
            test "REAR-000" = "$USB_LABEL" && continue
            LogPrint "Setting filesystem label to REAR-000"
            if ! e2label $rear_data_partition_device REAR-000 ; then
                Error "Could not label $rear_data_partition_device with REAR-000"
            fi
            USB_LABEL="$( e2label $rear_data_partition_device )"
            ;;
        btrfs)
            USB_LABEL="$( btrfs filesystem label $rear_data_partition_device )"
            test "REAR-000" = "$USB_LABEL" && continue
            LogPrint "Setting filesystem label to REAR-000"
            if ! btrfs filesystem label $rear_data_partition_device REAR-000 ; then
                Error "Could not label $rear_data_partition_device with REAR-000"
            fi
            USB_LABEL="$( btrfs filesystem label $rear_data_partition_device )"
            ;;
        (*)
            # ID_FS_TYPE can be 'unknown', cf. format/USB/default/200_check_usb_layout.sh
            return
            ;;
    esac
done

# Report the final result to the user:
LogPrint "Device $rear_data_partition_device has filesystem label '$USB_LABEL'"

