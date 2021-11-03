
# USB_FORMAT_ANSWER was set before by format/USB/default/200_check_usb_layout.sh
# FORMAT_FORCE may have been set by lib/format-workflow.sh
[[ "$USB_FORMAT_ANSWER" == "Yes" || "$FORMAT_FORCE" ]] || return 0

# $REAL_USB_DEVICE was set before by format/USB/default/200_check_usb_layout.sh
umount $REAL_USB_DEVICE &>/dev/null

# $RAW_USB_DEVICE was set before by format/USB/default/200_check_usb_layout.sh
LogPrint "Repartitioning $RAW_USB_DEVICE"

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
local MiB_bytes=$(( 1024 * 1024 ))

# After a partition was set up current_partition_number is increased by 1
# so that current_partition_number is the number of the first not-yet-existing partition
# i.e. current_partition_number is the number of the partition that can be set up next:
local current_partition_number=1

# current start byte of the next partition to add
local current_partition_start_byte=$(( USB_PARTITION_ALIGN_BLOCK_SIZE * MiB_bytes ))

# Flag for the partition wherefrom is booted which is the boot partition if exists
# or the data partition as fallback when there is no boot partition:
local boot_partition_flag="$USB_BOOT_PARTITION_FLAG"
if ! test $boot_partition_flag ; then
    # Set the right default flag if none was specified
    # cf. https://github.com/rear/rear/issues/1153
    case "$USB_DEVICE_PARTED_LABEL" in
        (msdos)
            boot_partition_flag="boot"
            ;;
        (gpt)
            boot_partition_flag="legacy_boot"
            ;;
        (*)
            Error "USB_DEVICE_PARTED_LABEL='$USB_DEVICE_PARTED_LABEL' (neither 'msdos' nor 'gpt')"
            ;;
    esac
fi

### Create partition table section

# Initialize USB disk via "parted mklabel" (create partition table)
# If not set use fallback value 'msdos' (same as the default value in default.conf):
test "msdos" = "$USB_DEVICE_PARTED_LABEL" -o "gpt" = "$USB_DEVICE_PARTED_LABEL" || USB_DEVICE_PARTED_LABEL="msdos"
LogPrint "Creating partition table of type $USB_DEVICE_PARTED_LABEL on $RAW_USB_DEVICE"
if ! parted -s $RAW_USB_DEVICE mklabel $USB_DEVICE_PARTED_LABEL ; then
    Error "Failed to create $USB_DEVICE_PARTED_LABEL partition table on $RAW_USB_DEVICE"
fi

### Create partitions section
# in order:
# * BIOS partition (GPT only) / partition gap aka empty space for MSDOS
# * EFI (in case of EFI)
# * boot partition (optional but encuraged)
# * backup/storage/data partition

# In case of GPT with BIOS boot we need a 'bios_grub' partition
# In case of MSDOS partition table we just need some free space in between the partition table and the first partition
# This partition should be the first one afaik this has a better chance to work with odd BIOS firmwares
if is_true "$FORMAT_BIOS" ; then
    if [[ "$USB_DEVICE_PARTED_LABEL" == "gpt" ]] ; then
        LogPrint "Making a BIOS bootable device $RAW_USB_DEVICE"
        # Create BIOS boot partition for GRUB2 second stage 'core.img'
        # cf. https://en.wikipedia.org/wiki/BIOS_boot_partition
        # and https://en.wikipedia.org/wiki/GUID_Partition_Table reads (excerpt)
        #   The UEFI specification stipulates that a minimum of 16,384 bytes,
        #   regardless of sector size, are allocated for the Partition Entry Array.
        #   Thus, on a disk with 512-byte sectors, at least 32 sectors are used for the Partition Entry Array,
        #   and the first usable block is LBA 34 or higher.
        #   While on a 4096-byte sectors disk, at least 4 sectors are used for the Partition Entry Array,
        #   and the first usable block is LBA 6 or higher.
        # So the first possible byte for a BIOS boot partition is
        # 512 * 34 = 17408 on a disk with 512-byte sectors and
        # 4096 * 6 = 24576 on a disk with 4096-byte sectors and
        # we assume using the maximum value 24576 will work for both cases
        # cf. https://github.com/rear/rear/pull/2656#issuecomment-880528455
        local bios_boot_partition_start_byte=24576
        LogPrint "Creating BIOS boot partition $RAW_USB_DEVICE$current_partition_number"
        # The BIOS boot partition goes up to (excluding) the byte where the boot partition starts:
        local bios_boot_partition_end_byte=$(( current_partition_start_byte - 1 ))
        if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $bios_boot_partition_start_byte $bios_boot_partition_end_byte ; then
            Error "Failed to create BIOS boot partition $RAW_USB_DEVICE$current_partition_number"
        fi
        # parted uses the bios_grub flag to also change the partition type to ef02
        LogPrint "Setting 'bios_grub' flag on BIOS boot partition $RAW_USB_DEVICE$current_partition_number"
        if ! parted -s $RAW_USB_DEVICE set $current_partition_number bios_grub on ; then
            Error "Failed to set 'bios_grub' flag on BIOS boot partition $RAW_USB_DEVICE$current_partition_number"
        fi
        # Partition 1 is the BIOS boot partition
        # so the number of the partition that can be set up next has to be one more (i.e. now 2):
        current_partition_number=$(( current_partition_number + 1 ))
    fi
fi

# In case of EFI boot we need a EFI system partition
if is_true "$FORMAT_EFI" ; then
    LogPrint "Making an EFI bootable device $RAW_USB_DEVICE"
    # Prompt user for size of EFI system partition on USB disk if no valid value is specified:
    while ! is_positive_integer $USB_UEFI_PART_SIZE ; do
        # When USB_UEFI_PART_SIZE is empty, do not falsely complain about "Invalid EFI partition size":
        test "$USB_UEFI_PART_SIZE" && LogPrintError "Invalid EFI system partition size USB_UEFI_PART_SIZE='$USB_UEFI_PART_SIZE' (must be positive integer)"
        USB_UEFI_PART_SIZE="$( UserInput -I USB_DEVICE_EFI_PARTITION_MIBS -p "Enter size for EFI system partition on $RAW_USB_DEVICE in MiB (default 512 MiB)" )"
        # Plain 'Enter' defaults to 512 MiB (same as the default value in default.conf):
        test "$USB_UEFI_PART_SIZE" || USB_UEFI_PART_SIZE="512"
    done

    # Round UEFI partition size to nearest block size to make the 2nd partition (the data partition) also align to the block size:
    USB_UEFI_PART_SIZE=$(( ( USB_UEFI_PART_SIZE + ( USB_PARTITION_ALIGN_BLOCK_SIZE / 2 ) ) / USB_PARTITION_ALIGN_BLOCK_SIZE * USB_PARTITION_ALIGN_BLOCK_SIZE ))
    LogPrint "Creating EFI system partition $RAW_USB_DEVICE$current_partition_number with size $USB_UEFI_PART_SIZE MiB aligned at $USB_PARTITION_ALIGN_BLOCK_SIZE MiB"
    # Calculate byte values:
    local efi_partition_size_bytes=$(( USB_UEFI_PART_SIZE * MiB_bytes ))
    # The end byte is the last byte that belongs to that partition so that one must be careful to use "start_byte + partition_size_in_bytes - 1":
    local efi_partition_end_byte=$(( current_partition_start_byte + efi_partition_size_bytes - 1 ))
    if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $current_partition_start_byte $efi_partition_end_byte ; then
        Error "Failed to create EFI system partition $RAW_USB_DEVICE$current_partition_number"
    fi
    # Set the right flag for the EFI partition:
    LogPrint "Setting 'esp' flag on EFI partition $RAW_USB_DEVICE$current_partition_number"
    if ! parted -s $RAW_USB_DEVICE set $current_partition_number esp on ; then
        Error "Failed to set 'esp' flag on EFI partition $RAW_USB_DEVICE$current_partition_number"
    fi
    # Partition 1 is the EFI system partition (vfat partition) on which EFI/BOOT/BOOTX86.EFI resides
    # so the number of the partition that can be set up next has to be one more (i.e. now 2):
    current_partition_number=$(( current_partition_number + 1 ))
    # Calculate byte value for the start of the subsequent partition:
    current_partition_start_byte=$(( efi_partition_end_byte + 1 ))
fi

# A boot partition is never strictly required but allows for a clear separation of concerns
# Also the EFI partition could be misused to also store boot details
if is_positive_integer $USB_BOOT_PART_SIZE ; then
    # Create a boot partition for the bootloader config/plugins/modules, the kernel and the ReaR recovery system initrd.
    # Round boot partition size to nearest block size to make the next partition (the data partition) also align to the block size:
    USB_BOOT_PART_SIZE=$(( ( USB_BOOT_PART_SIZE + ( USB_PARTITION_ALIGN_BLOCK_SIZE / 2 ) ) / USB_PARTITION_ALIGN_BLOCK_SIZE * USB_PARTITION_ALIGN_BLOCK_SIZE ))
    LogPrint "Creating boot partition $RAW_USB_DEVICE$current_partition_number with size $USB_BOOT_PART_SIZE MiB aligned at $USB_PARTITION_ALIGN_BLOCK_SIZE MiB"
    # Calculate byte values:
    local boot_partition_size_bytes=$(( USB_BOOT_PART_SIZE * MiB_bytes ))
    # The end byte is the last byte that belongs to that partition so that one must be careful to use "start_byte + partition_size_in_bytes - 1":
    local boot_partition_end_byte=$(( current_partition_start_byte + boot_partition_size_bytes - 1 ))
    if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $current_partition_start_byte $boot_partition_end_byte ; then
        Error "Failed to create boot partition $RAW_USB_DEVICE$current_partition_number"
    fi
    # Set the right flag for the boot partition unless no flag should be set:
    if ! is_false $boot_partition_flag ; then
        LogPrint "Setting '$boot_partition_flag' flag on boot partition $RAW_USB_DEVICE$current_partition_number"
        if ! parted -s $RAW_USB_DEVICE set $current_partition_number $boot_partition_flag on ; then
            Error "Failed to set '$boot_partition_flag' flag on boot partition $RAW_USB_DEVICE$current_partition_number"
        fi
        # When the flag was set for the boot partition do not also set this flag for the data partition below:
        boot_partition_flag="false"
    fi
    # With a boot partition the number of the partition that can be set up next has to be one more
    # i.e. it is now 3 when also a BIOS boot partition was created and 2 otherwise:
    current_partition_number=$(( current_partition_number + 1 ))  
    # Calculate byte value for the start of the subsequent partition:
    current_partition_start_byte=$(( boot_partition_end_byte + 1 ))
fi

# USB_DATA_PARTITION_NUMBER is also needed in the subsequent format/USB/default/350_label_usb_disk.sh
USB_DATA_PARTITION_NUMBER=$current_partition_number

LogPrint "Creating ReaR data partition $RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER up to ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% of $RAW_USB_DEVICE"
# Older parted versions (at least GNU Parted 1.6.25.1 on SLE10) support the '%' unit (cf. https://github.com/rear/rear/issues/1270):
if ! parted -s $RAW_USB_DEVICE unit B mkpart primary $current_partition_start_byte ${USB_DEVICE_FILESYSTEM_PERCENTAGE}% ; then
    Error "Failed to create ReaR data partition $RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER"
fi
# Set the right flag for the data partition unless no flag should be set or when it was already set for the boot partition above:
if ! is_false $boot_partition_flag ; then
    LogPrint "Setting '$boot_partition_flag' flag on ReaR data partition $RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER"
    if ! parted -s $RAW_USB_DEVICE set $USB_DATA_PARTITION_NUMBER $boot_partition_flag on ; then
        Error "Failed to set '$boot_partition_flag' flag on ReaR data partition $RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER"
    fi
fi

# signal the kernel it should re-read the partition table and update the devfs
# so mkfs writes to the correct byte offsets of the partition
partprobe $RAW_USB_DEVICE
# Wait until udev has had the time to kick in
sleep 5

### make FS and label section

if is_true "$FORMAT_EFI" ; then
    local rear_efi_partition_number="1"
    if is_true "$FORMAT_BIOS" && [[ "$USB_DEVICE_PARTED_LABEL" == "gpt" ]] ; then
        rear_efi_partition_number="2"
    fi
    # Detect loopback device parition naming
    # on loop devices the first partition is named e.g. loop0p1
    # instead of e.g. sdb1 on usual (USB) disks
    # cf. https://github.com/rear/rear/pull/2555
    local rear_efi_partition_device="${RAW_USB_DEVICE}${rear_efi_partition_number}"
    if [ ! -b "$rear_efi_partition_device" ] && [ -b "${RAW_USB_DEVICE}p${rear_efi_partition_number}" ] ; then
        rear_efi_partition_device="${RAW_USB_DEVICE}p${rear_efi_partition_number}"
    fi
    LogPrint "Creating vfat filesystem on EFI system partition on $rear_efi_partition_device"
    # Make a FAT filesystem on the EFI system partition
    # cf. https://github.com/rear/rear/issues/2575
    # and output/ISO/Linux-i386/700_create_efibootimg.sh
    # and output/RAWDISK/Linux-i386/280_create_bootable_disk_image.sh
    # Let mkfs.vfat automatically select the FAT type based on the size.
    # I.e. do not use a '-F 16' or '-F 32' option and hope for the best:
    if ! mkfs.vfat $v -n REAR-EFI $rear_efi_partition_device ; then
        Error "Failed to create vfat filesystem on EFI system partition $rear_efi_partition_device"
    fi
fi

if is_positive_integer $USB_BOOT_PART_SIZE ; then
    local rear_boot_partition_device="$RAW_USB_DEVICE$(( $USB_DATA_PARTITION_NUMBER -1 ))"
    # To be on the safe side have the boot partition fallback label "REARBOOT" only 8 characters long:
    test "$USB_DEVICE_BOOT_LABEL" || USB_DEVICE_BOOT_LABEL="REARBOOT"
    LogPrint "Creating ext2 filesystem with label '$USB_DEVICE_BOOT_LABEL' on boot partition $rear_boot_partition_device"
    if ! mkfs.ext2 -L "$USB_DEVICE_BOOT_LABEL" $rear_boot_partition_device ; then
        Error "Failed to create ext2 filesystem on boot partition $rear_boot_partition_device"
    fi
fi

# Detect loopback device parition naming (same logic as above)
local data_partition_device="$RAW_USB_DEVICE$USB_DATA_PARTITION_NUMBER"
if [ ! -b "$data_partition_device" ] && [ -b "${RAW_USB_DEVICE}p${USB_DATA_PARTITION_NUMBER}" ] ; then
    data_partition_device="${RAW_USB_DEVICE}p${USB_DATA_PARTITION_NUMBER}"
fi

LogPrint "Creating $USB_DEVICE_FILESYSTEM filesystem with label '$USB_DEVICE_FILESYSTEM_LABEL' on ReaR data partition $data_partition_device"
if ! mkfs.$USB_DEVICE_FILESYSTEM -L "$USB_DEVICE_FILESYSTEM_LABEL" $USB_DEVICE_FILESYSTEM_PARAMS $data_partition_device ; then
    Error "Failed to create $USB_DEVICE_FILESYSTEM filesystem on ReaR data partition $data_partition_device"
fi

LogPrint "Adjusting filesystem parameters on ReaR data partition $data_partition_device"
if ! tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered $data_partition_device ; then
    Error "Failed to adjust filesystem parameters on ReaR data partition $data_partition_device"
fi

# signal the kernel to read the partition table again to get /dev/disk/by-label
partprobe $RAW_USB_DEVICE
# Wait until udev has had the time to kick in
sleep 5
