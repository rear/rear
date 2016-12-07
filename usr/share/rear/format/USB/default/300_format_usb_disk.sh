
# $USB_format_answer is filled by 200_check_usb_layout.sh
[[ "$USB_format_answer" == "Yes" || "$FORCE" ]] || return 0

umount $REAL_USB_DEVICE &>/dev/null

LogPrint "Repartitioning '$RAW_USB_DEVICE'"

echo "Yes" | parted -s $RAW_USB_DEVICE mklabel msdos >&2
StopIfError "Could not create initial msdos partition table on '$REAL_USB_DEVICE'"

test "$USB_DEVICE_FILESYSTEM_PERCENTAGE" || USB_DEVICE_FILESYSTEM_PERCENTAGE="100"

if [[ "$EFI" == "y" ]]; then
    LogPrint "The --efi toggle was used with format - make an EFI bootable device '$REAL_USB_DEVICE'"

    # Prompt user for size of EFI partition on USB disk
    # Pressing Enter (\n) will use USB_UEFI_PART_SIZE (default in default.conf) or fallback here:
    test "$USB_UEFI_PART_SIZE" || USB_UEFI_PART_SIZE="100"
    echo -n "Enter size of EFI partition on '$REAL_USB_DEVICE' in MB [default $USB_UEFI_PART_SIZE MB]: "
    read efi_part_size

    # Check if user entered unsigned integer larger than 0
    if [[ "${efi_part_size}" =~ ^[0-9]+$ && ${efi_part_size} > 0 ]]; then
        USB_UEFI_PART_SIZE=${efi_part_size}
        LogPrint "Creating EFI partition on '$REAL_USB_DEVICE' with size $USB_UEFI_PART_SIZE MB."
    # We did not read anything, used defaults
    elif [[ -z ${efi_part_size} ]]; then
        LogPrint "Creating EFI partition on '$REAL_USB_DEVICE' with default size $USB_UEFI_PART_SIZE MB."
    # User input was not correct ...
    else
        Error "Bad input for EFI partition size."
    fi

    echo "Yes" | parted -s $RAW_USB_DEVICE -- mklabel gpt mkpart primary 0 ${USB_UEFI_PART_SIZE}Mib mkpart primary ${USB_UEFI_PART_SIZE}Mib ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% >&2

    StopIfError "Could not create GPT partitions on '$REAL_USB_DEVICE'"
    # partition 1 is the ESP (vfat partition) on which EFI/BOOT/BOOTX86.EFI resides
    ParNr=2
else
    echo "Yes" | parted -s $RAW_USB_DEVICE mkpart primary 0 ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% >&2
    StopIfError "Could not create a primary partition on '$REAL_USB_DEVICE'"
    ParNr=1
fi

echo "Yes" | parted -s $RAW_USB_DEVICE set 1 boot on >&2
StopIfError "Could not make primary partition bootable on '$REAL_USB_DEVICE'"

partprobe $RAW_USB_DEVICE

# Wait until udev has had the time to kick in
sleep 5

if [[ "$EFI" == "y" ]]; then
    LogPrint "Creating vfat filesystem on EFI system partition (ESP) '${RAW_USB_DEVICE}1'"
    mkfs.vfat $v -F 16 -n REAR-EFI ${RAW_USB_DEVICE}1 >&2

    # create link for EFI partition in /dev/disk/by-label
    partprobe $RAW_USB_DEVICE
    sleep 5
fi

LogPrint "Creating $USB_DEVICE_FILESYSTEM filesystem on '${RAW_USB_DEVICE}${ParNr}'"
mkfs.$USB_DEVICE_FILESYSTEM -L REAR-000 ${RAW_USB_DEVICE}${ParNr} >&2
StopIfError "Could not format '${RAW_USB_DEVICE}${ParNr}' with $USB_DEVICE_FILESYSTEM filesystem"

tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered ${RAW_USB_DEVICE}${ParNr} >&2
StopIfError "Failed to change filesystem characteristics on '${RAW_USB_DEVICE}${ParNr}'"

