# Create the raw disk image
#
# The disk image will be created as a bootable disk image supporting booting via EFI and/or Legacy BIOS if the
# respective bootloaders are available. This script expects an EFI bootloader to be prepared in advance in a
# staging directory.
#
# If an EFI bootloader has been prepared, $RAWDISK_BOOT_EFI_STAGING_ROOT must point to the EFI staging directory.
#


### Check prerequisites

local use_syslinux_legacy=no
if has_binary syslinux; then
    if is_true "${RAWDISK_BOOT_EXCLUDE_SYSLINUX_LEGACY:-no}"; then
        LogPrint "DISABLED: Using syslinux to create a BIOS Legacy bootloader"
    else
        use_syslinux_legacy=yes
    fi
fi

if ([[ -z "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] && ! is_true $use_syslinux_legacy); then
    Error "Creating a raw disk image requires an EFI bootloader or syslinux"
fi


### Create an initial disk image

# Wait for file systems to settle before trying to determine partition content size
sync
sleep 3  # should not be strictly necessary as Linux sync(2) waits until data is written

# Determine the appropriate size (adding 1 MiB for plus 7% for file system overhead/reserve)
local staged_boot_partition_contents=( "$KERNEL_FILE" "$TMP_DIR/$REAR_INITRD_FILENAME" )
[[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] && staged_boot_partition_contents+=( "$RAWDISK_BOOT_EFI_STAGING_ROOT" )
local disk_image_size_MiB="$(du -m --summarize --total "${staged_boot_partition_contents[@]}" | awk '$2 == "total" { printf("%.0f\n", 1 + ($1 * 1.07) + .5); }')"

local full_disk_name="${RAWDISK_IMAGE_NAME:-rear-$HOSTNAME}.raw"
local disk_image="$TMP_DIR/$full_disk_name"

LogPrint "Creating $disk_image_size_MiB MiB raw disk image \"$full_disk_name\""

dd if=/dev/zero of="$disk_image" bs=1M count="$disk_image_size_MiB"
[ -f "$disk_image" ] || Error "Could not create initial disk image file $disk_image"


### Create a GPT partition table

# Determine the configuration for the boot partition
local typecode="8300"  # Linux partition for non-EFI booting
[[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] && typecode="ef00"  # EFI System partition if an EFI bootloader has been prepared

local legacy_boot_option=""
is_true $use_syslinux_legacy && legacy_boot_option="--attributes=1:set:2"  # mark partition as Legacy BIOS-bootable

sgdisk --new 1::0 --typecode=1:"$typecode" --change-name=1:"${RAWDISK_GPT_PARTITION_NAME:-Rescue System}" $legacy_boot_option "$disk_image"
StopIfError "Could not create GPT partition table on $disk_image"

Log "Raw disk image partition table:"
gdisk -l "$disk_image" >&2


### Create block devices representing the raw disk image

local disk_device  # separate 'local' statement to avoid losing $(...) exit status - cf. https://stackoverflow.com/a/10397996
disk_device="$(losetup --show --find "$disk_image")"
StopIfError "Could not create loop device on $disk_image"
AddExitTask "losetup -d $disk_device >&2"

partprobe "$disk_device" || Error "Could not make the kernel recognize loop device partitions"
local boot_partition="${disk_device}p1"


### Create and populate the boot file system

# Note: Having a small EFI System Partition (ESP) might introduce problems:
# - The UEFI spec seems to require a FAT32 EFI System Partition (ESP).
# - syslinux/Legacy BIOS fails to install on small FAT32 partitions with "syslinux: zero FAT sectors (FAT12/16)".
# - Some firmwares fail to boot from small FAT32 partitions.
# - Some firmwares fail to boot from FAT16 partitions.
# See:
# - http://www.rodsbooks.com/efi-bootloaders/principles.html
# - http://lists.openembedded.org/pipermail/openembedded-core/2012-January/055999.html
# As there seems to be no silver bullet, let mkfs.vfat choose the 'right' FAT partition type based on partition size
# (i.e. do not use the '-F 32' option) and hope for the best...
mkfs.vfat $v "$boot_partition" -n "${RAWDISK_FAT_VOLUME_LABEL:-RESCUE SYS}" || Error "Could not create boot file system"

local boot_partition_root="$TMP_DIR/boot"
mkdir -p "$boot_partition_root" || Error "Could not create boot file system mount point"
mount "$boot_partition" "$boot_partition_root" || Error "Could not mount boot file system"
AddExitTask "umount $boot_partition_root >&2"

# Populate the boot file system with kernel, initrd and possibly EFI bootloader
cp -rL $v "${staged_boot_partition_contents[@]}" "$boot_partition_root" >&2 || Error "Could not populate boot partition"


### Install syslinux stuff as required

# Note: This may add files to the boot file system *and* modify the boot sector directly within the raw disk image.
# After installing a Legacy BIOS bootloader, files on the boot partition should not change: The bootloader file is
# patched during installation with a list of its exact on-disk block locations.

if has_binary syslinux; then
    # Install syslinux configuration, which may be shared between syslinux/EFI and syslinux/Legacy bootloaders.
    local syslinux_installation_dir="$boot_partition_root/syslinux"
    mkdir -p "$syslinux_installation_dir" || Error "Could not create syslinux bootloader directory"
    cat > "$syslinux_installation_dir/syslinux.cfg" << EOF
DEFAULT rescue
LABEL rescue
 SAY
 SAY ${RAWDISK_BOOT_SYSLINUX_START_INFORMATION:-Starting the rescue system...}
 KERNEL ../$(basename "$KERNEL_FILE")
 APPEND $KERNEL_CMDLINE
 INITRD ../$REAR_INITRD_FILENAME
EOF
    StopIfError "Could not write syslinux bootloader configuration"

    if is_true $use_syslinux_legacy; then
        LogPrint "Using syslinux to install a Legacy BIOS bootloader"

        # Install syslinux as Legacy BIOS bootloader
        syslinux --directory "/syslinux" --install "$boot_partition"
        StopIfError "Could not install Legacy BIOS bootloader (syslinux)"

        # Install the BIOS boot sector
        dd if="$(find_syslinux_file gptmbr.bin)" of="$disk_device" bs=440 count=1 oflag=sync
        StopIfError "Could not install Legacy BIOS boot sector (syslinux)"
    fi
fi

Log "Raw disk boot partition capacity after copying:"
df -h "$boot_partition_root" >&2


### Allow examining the boot file system and loop device for debugging

if is_true ${RAWDISK_DEBUG:-no}; then
    LogUserOutput "Entering shell to examine the raw disk's boot file system, exit to continue:"
    (cd "$boot_partition_root"; bash) <&6 >&7 2>&8
fi


### Unmount the boot partition, release the loop device

umount "$boot_partition_root" || Error "Could not unmount boot file system"
RemoveExitTask "umount $boot_partition_root >&2"
losetup -d "$disk_device" || Error "Could not delete loop device"
RemoveExitTask "losetup -d $disk_device >&2"


### Compress the disk image on request
if [[ -n "$RAWDISK_IMAGE_COMPRESSION_COMMAND" ]]; then
    $RAWDISK_IMAGE_COMPRESSION_COMMAND "$disk_image"
    StopIfError "Could not compress disk image using <<$RAWDISK_IMAGE_COMPRESSION_COMMAND \"$disk_image\">>"
    disk_image="$(echo "$disk_image"*)"
    [[ -f "$disk_image" ]] || Error "Could not find compressed disk image ${disk_image}*"
fi


### Add disk the image to the result files

RESULT_FILES+=( "$disk_image" )
