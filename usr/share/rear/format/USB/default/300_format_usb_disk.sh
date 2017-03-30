
# $USB_format_answer is filled by 200_check_usb_layout.sh
[[ "$USB_format_answer" == "Yes" || "$FORCE" ]] || return 0

umount $REAL_USB_DEVICE &>/dev/null

LogPrint "Repartitioning '$RAW_USB_DEVICE'"

# If not set use fallback value 100% (same as the default value in default.conf):
test "$USB_DEVICE_FILESYSTEM_PERCENTAGE" || USB_DEVICE_FILESYSTEM_PERCENTAGE="100"

# If not set use fallback value 8 MiB (same as the default value in default.conf):
test $USB_PARTITION_ALIGN_BLOCK_SIZE || USB_PARTITION_ALIGN_BLOCK_SIZE="8"
# Block size must be an integer (test "1.5" -eq "1.5" fails with bash error "integer expression expected") but
# that bash error is not logged to avoid that it looks as if there is a bash syntax error in the script code here:
test "$USB_PARTITION_ALIGN_BLOCK_SIZE" -eq "$USB_PARTITION_ALIGN_BLOCK_SIZE" 2>/dev/null || USB_PARTITION_ALIGN_BLOCK_SIZE="8"
# Block size must be 1 or greater:
test $USB_PARTITION_ALIGN_BLOCK_SIZE -ge 1 || USB_PARTITION_ALIGN_BLOCK_SIZE="1"

# Older parted versions do not support IEC binary units like MiB or GiB (cf. https://github.com/rear/rear/issues/1270)
# so that parted is called with bytes 'B' as unit to be backward compatible:
MiB_bytes=$(( 1024 * 1024 ))

if is_true "$EFI" ; then
    LogPrint "The --efi toggle was used with format - making an EFI bootable device '$RAW_USB_DEVICE'"
    # Prompt user for size of EFI system partition on USB disk if no valid value is specified:
    while ! [[ "$USB_UEFI_PART_SIZE" =~ ^[0-9]+$ && $USB_UEFI_PART_SIZE > 0 ]] ; do
        # When USB_UEFI_PART_SIZE is empty, do not tell about "Invalid EFI partition size value":
        test "$USB_UEFI_PART_SIZE" && echo "${MESSAGE_PREFIX}Invalid EFI system partition size value '$USB_UEFI_PART_SIZE' (must be unsigned integer larger than 0)"
        echo -n "${MESSAGE_PREFIX}Enter size for EFI system partition on '$RAW_USB_DEVICE' in MiB (plain 'Enter' defaults to 200 MiB): "
        read USB_UEFI_PART_SIZE
        # Plain 'Enter' defaults to 200 MiB (same as the default value in default.conf):
        test "$USB_UEFI_PART_SIZE" || USB_UEFI_PART_SIZE="200"
    done
    LogPrint "Creating GUID partition table (GPT) on '$RAW_USB_DEVICE'"
    if ! parted -s $RAW_USB_DEVICE mklabel gpt >&2 ; then
        Error "Failed to create GPT partition table on '$RAW_USB_DEVICE'"
    fi
    # Round UEFI partition size to nearest block size to make the 2nd partition (the ReaR data partition) also align to the block size:
    USB_UEFI_PART_SIZE=$(( ( USB_UEFI_PART_SIZE + ( USB_PARTITION_ALIGN_BLOCK_SIZE / 2 ) ) / USB_PARTITION_ALIGN_BLOCK_SIZE * USB_PARTITION_ALIGN_BLOCK_SIZE ))
    LogPrint "Creating EFI system partition with size $USB_UEFI_PART_SIZE MiB aligned at $USB_PARTITION_ALIGN_BLOCK_SIZE MiB on '$RAW_USB_DEVICE'"
    # Calculate byte values:
    efi_partition_start_byte=$(( USB_PARTITION_ALIGN_BLOCK_SIZE * MiB_bytes ))
    efi_partition_size_bytes=$(( USB_UEFI_PART_SIZE * MiB_bytes ))
    # The end byte is the last byte that belongs to that partition so that one must be careful to use "start_byte + partition_size_in_bytes - 1":
    efi_partition_end_byte=$(( efi_partition_start_byte + efi_partition_size_bytes - 1 ))
    if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $efi_partition_start_byte $efi_partition_end_byte >&2 ; then
        Error "Failed to create EFI system partition on '$RAW_USB_DEVICE'"
    fi
    # Calculate byte value for the start of the subsequent ReaR data partition:
    data_partition_start_byte=$(( efi_partition_end_byte + 1 ))
    # Partition 1 is the EFI system partition (vfat partition) on which EFI/BOOT/BOOTX86.EFI resides.
    # rear_data_partition_number is used below and in the subsequent 350_label_usb_disk.sh script for the ReaR data partition:
    rear_data_partition_number=2
else
    # If not set use fallback value 'msdos' (same as the default value in default.conf):
    test "msdos" = "$USB_DEVICE_PARTED_LABEL" -o "gpt" = "$USB_DEVICE_PARTED_LABEL" || USB_DEVICE_PARTED_LABEL="msdos"
    LogPrint "Creating partition table of type '$USB_DEVICE_PARTED_LABEL' on '$RAW_USB_DEVICE'"
    if ! parted -s $RAW_USB_DEVICE mklabel $USB_DEVICE_PARTED_LABEL >&2 ; then
        Error "Failed to create $USB_DEVICE_PARTED_LABEL partition table on '$RAW_USB_DEVICE'"
    fi
    # Calculate byte value for the start of the subsequent ReaR data partition:
    data_partition_start_byte=$(( USB_PARTITION_ALIGN_BLOCK_SIZE * MiB_bytes ))
    # rear_data_partition_number is used below and in the subsequent 350_label_usb_disk.sh script for the ReaR data partition:
    rear_data_partition_number=1
fi
LogPrint "Creating ReaR data partition up to ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% of '$RAW_USB_DEVICE'"
# Older parted versions (at least GNU Parted 1.6.25.1 on SLE10) support the '%' unit (cf. https://github.com/rear/rear/issues/1270):
if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $data_partition_start_byte ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% >&2 ; then
    Error "Failed to create ReaR data partition on '$RAW_USB_DEVICE'"
fi

# Choose correct boot flag for partition table (see issue #1153)
local boot_flag
case "$USB_DEVICE_PARTED_LABEL" in
    "msdos")
        boot_flag="boot"
        ;;
    "gpt")
        boot_flag="legacy_boot"
        ;;
    *)
        Error "USB_DEVICE_PARTED_LABEL is incorrectly set, please check your settings."
        ;;
esac

LogPrint "Setting '$boot_flag' flag on $RAW_USB_DEVICE"
if ! parted -s $RAW_USB_DEVICE set 1 $boot_flag on >&2 ; then
    Error "Could not make first partition bootable on '$RAW_USB_DEVICE'"
fi

partprobe $RAW_USB_DEVICE
# Wait until udev has had the time to kick in
sleep 5

if is_true "$EFI" ; then
    LogPrint "Creating vfat filesystem on EFI system partition on '${RAW_USB_DEVICE}1'"
    if ! mkfs.vfat $v -F 16 -n REAR-EFI ${RAW_USB_DEVICE}1 >&2 ; then
        Error "Failed to create vfat filesystem on '${RAW_USB_DEVICE}1'"
    fi
    # create link for EFI partition in /dev/disk/by-label
    partprobe $RAW_USB_DEVICE
    # Wait until udev has had the time to kick in
    sleep 5
fi

local rear_data_partition_device="$RAW_USB_DEVICE$rear_data_partition_number"

LogPrint "Creating $USB_DEVICE_FILESYSTEM filesystem with label 'REAR-000' on '$rear_data_partition_device'"
if ! mkfs.$USB_DEVICE_FILESYSTEM -L REAR-000 ${USB_DEVICE_FILESYSTEM_PARAMS} $rear_data_partition_device >&2 ; then
    Error "Failed to create $USB_DEVICE_FILESYSTEM filesystem on '$rear_data_partition_device'"
fi

LogPrint "Adjusting filesystem parameters on '$rear_data_partition_device'"
if ! tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered $rear_data_partition_device >&2 ; then
    Error "Failed to adjust filesystem parameters on '$rear_data_partition_device'"
fi

