# Use syslinux to create an EFI bootloader
#


### Check prerequisites

# Run only if no EFI bootloader has been created yet and syslinux is available
([[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] || ! has_binary syslinux) && return 0

# Find syslinux files (unfortunately, installations vary in locations and naming)
local syslinux_efi="$(find /usr/lib /usr/share -iname syslinux.efi -print | grep -i "/efi64/" | head -n 1)"
local ldlinux_e64="$(find /usr/lib /usr/share -iname ldlinux.e64 -print | head -n 1 )"

# Pass if required syslinux EFI files cannot be found
([[ -f "$syslinux_efi" ]] && [[ -f "$ldlinux_e64" ]]) || return 0

if is_true "${RAWDISK_BOOT_EXCLUDE_SYSLINUX_EFI:-no}"; then
    LogPrint "DISABLED: Using syslinux to create an EFI bootloader"
    return 0
fi


### Copy syslinux files into the staging directory

LogPrint "Using syslinux to create an EFI bootloader"

RAWDISK_BOOT_EFI_STAGING_ROOT="$TMP_DIR/EFI"
local efi_boot_directory="$RAWDISK_BOOT_EFI_STAGING_ROOT/BOOT"

mkdir $v -p "$efi_boot_directory" || Error "Could not create $efi_boot_directory"

cp $v "$syslinux_efi" "$efi_boot_directory/BOOTX64.EFI" >&2
cp $v "$ldlinux_e64" "$efi_boot_directory" >&2


# Note: 280_create_bootable_disk_image.sh will install a syslinux configuration
# which will be shared between syslinux/EFI and syslinux/Legacy bootloaders.
