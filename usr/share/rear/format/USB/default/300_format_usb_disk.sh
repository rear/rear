
# $USB_format_answer is filled by 200_check_usb_layout.sh
[[ "$USB_format_answer" == "Yes" || "$FORCE" ]] || return 0

umount $REAL_USB_DEVICE &>/dev/null

LogPrint "Repartitioning '$RAW_USB_DEVICE'"

test "$USB_DEVICE_FILESYSTEM_PERCENTAGE" || USB_DEVICE_FILESYSTEM_PERCENTAGE="100"

if [[ "$EFI" == "y" ]]; then
    LogPrint "The --efi toggle was used with format - making an EFI bootable device '$RAW_USB_DEVICE'"
    # Prompt user for size of EFI system partition on USB disk if no valid value is specified:
    while ! [[ "$USB_UEFI_PART_SIZE" =~ ^[0-9]+$ && $USB_UEFI_PART_SIZE > 0 ]] ; do
        # When USB_UEFI_PART_SIZE is empty, do not tell about "Invalid EFI partition size value":
        test "$USB_UEFI_PART_SIZE" && echo "${MESSAGE_PREFIX}Invalid EFI system partition size value '$USB_UEFI_PART_SIZE' (must be unsigned integer larger than 0)"
        echo -n "${MESSAGE_PREFIX}Enter size for EFI system partition on '$RAW_USB_DEVICE' in MB (plain 'Enter' defaults to 100 MB): "
        read USB_UEFI_PART_SIZE
        # Plain 'Enter' defaults to 100 MB (same as the default value in default.conf):
        test "$USB_UEFI_PART_SIZE" || USB_UEFI_PART_SIZE="100"
    done
    LogPrint "Creating GUID partition table (GPT) on '$RAW_USB_DEVICE'"
    parted -s $RAW_USB_DEVICE mklabel gpt >&2 || Error "Failed to create GPT partition table on '$RAW_USB_DEVICE'"
    test $USB_PARTITION_ALIGN_BLOCK_SIZE || USB_PARTITION_ALIGN_BLOCK_SIZE="8" # MiB
    # Block size must be an integer of 1 or greater (the first test checks for integer: test "1.5" -eq "1.5" fails with bash error "integer expression expected"):
    test "$USB_PARTITION_ALIGN_BLOCK_SIZE" -eq "$USB_PARTITION_ALIGN_BLOCK_SIZE" 2>/dev/null || USB_PARTITION_ALIGN_BLOCK_SIZE="8" # MiB
    test $USB_PARTITION_ALIGN_BLOCK_SIZE -ge 1 || USB_PARTITION_ALIGN_BLOCK_SIZE="1"
    # Round UEFI partition size to nearest block size. This to make the 2nd partition also align to the block size:
    USB_UEFI_PART_SIZE=$((($USB_UEFI_PART_SIZE + ($USB_PARTITION_ALIGN_BLOCK_SIZE / 2)) / $USB_PARTITION_ALIGN_BLOCK_SIZE * $USB_PARTITION_ALIGN_BLOCK_SIZE))
    LogPrint "Creating EFI system partition with size $USB_UEFI_PART_SIZE MiB aligned at $USB_PARTITION_ALIGN_BLOCK_SIZE MiB on '$RAW_USB_DEVICE'"
    parted -s $RAW_USB_DEVICE mkpart primary ${USB_PARTITION_ALIGN_BLOCK_SIZE}Mib "$((${USB_PARTITION_ALIGN_BLOCK_SIZE} + ${USB_UEFI_PART_SIZE}))"Mib || Error "Failed to create EFI system partition on '$RAW_USB_DEVICE'"
    LogPrint "Creating ReaR data partition up to ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% of '$RAW_USB_DEVICE'"
    parted -s $RAW_USB_DEVICE mkpart primary "$((${USB_PARTITION_ALIGN_BLOCK_SIZE} + ${USB_UEFI_PART_SIZE}))"Mib ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% >&2 || Error "Failed to create ReaR data partition on '$RAW_USB_DEVICE'"
    # partition 1 is the EFI system partition (vfat partition) on which EFI/BOOT/BOOTX86.EFI resides
    ParNr=2
else
    test "msdos" = "$USB_DEVICE_PARTED_LABEL" -o "gpt" = "$USB_DEVICE_PARTED_LABEL" || USB_DEVICE_PARTED_LABEL="msdos"
    LogPrint "Creating partition table of type '$USB_DEVICE_PARTED_LABEL' on '$RAW_USB_DEVICE'"
    parted -s $RAW_USB_DEVICE mklabel $USB_DEVICE_PARTED_LABEL >&2 || Error "Failed to create $USB_DEVICE_PARTED_LABEL partition table on '$RAW_USB_DEVICE'"
    LogPrint "Creating ReaR data partition up to ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% of '$RAW_USB_DEVICE'"
    parted -s $RAW_USB_DEVICE mkpart primary 0 ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% >&2 || Error "Failed to create ReaR data partition on '$RAW_USB_DEVICE'"
    ParNr=1
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
parted -s $RAW_USB_DEVICE set 1 $boot_flag on >&2 || Error "Could not make first partition bootable on '$RAW_USB_DEVICE'"

partprobe $RAW_USB_DEVICE
# Wait until udev has had the time to kick in
sleep 5

if [[ "$EFI" == "y" ]]; then
    LogPrint "Creating vfat filesystem on EFI system partition on '${RAW_USB_DEVICE}1'"
    mkfs.vfat $v -F 16 -n REAR-EFI ${RAW_USB_DEVICE}1 >&2 || Error "Failed to create vfat filesystem on '${RAW_USB_DEVICE}1'"
    # create link for EFI partition in /dev/disk/by-label
    partprobe $RAW_USB_DEVICE
    # Wait until udev has had the time to kick in
    sleep 5
fi

LogPrint "Creating $USB_DEVICE_FILESYSTEM filesystem with label 'REAR-000' on '${RAW_USB_DEVICE}${ParNr}'"
mkfs.$USB_DEVICE_FILESYSTEM -L REAR-000 ${USB_DEVICE_FILESYSTEM_PARAMS} ${RAW_USB_DEVICE}${ParNr} >&2 || Error "Failed to create $USB_DEVICE_FILESYSTEM filesystem on '${RAW_USB_DEVICE}${ParNr}'"

LogPrint "Adjusting filesystem parameters on '${RAW_USB_DEVICE}${ParNr}'"
tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered ${RAW_USB_DEVICE}${ParNr} >&2 || Error "Failed to adjust filesystem parameters on '${RAW_USB_DEVICE}${ParNr}'"

