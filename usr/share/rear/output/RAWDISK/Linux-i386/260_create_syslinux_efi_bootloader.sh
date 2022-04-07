# Use syslinux to create an EFI bootloader
#


### Check prerequisites

# Run only if
# a) no EFI bootloader has been created yet and
# b) secure boot (which is assumed to require Grub) is disabled and
# c) syslinux is available.
([[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" || -n "$SECURE_BOOT_BOOTLOADER" ]] || ! has_binary syslinux) && return 0

# Find syslinux files (unfortunately, installations vary in locations and naming)
local syslinux_efi="$(find /usr/lib /usr/share -iname syslinux.efi -print | grep -i "/efi64/" | head -n 1)"
local ldlinux_e64="$(find /usr/lib /usr/share -iname ldlinux.e64 -print | head -n 1 )"

# Pass if required syslinux EFI files cannot be found
# Avoid SC2235: Use { ..; } instead of (..) to avoid subshell overhead
# cf. https://github.com/koalaman/shellcheck/wiki/SC2235
{ [[ -f "$syslinux_efi" ]] && [[ -f "$ldlinux_e64" ]] ; } || return 0

if is_true "${RAWDISK_BOOT_EXCLUDE_SYSLINUX_EFI:-no}"; then
    LogPrint "DISABLED: Using syslinux to create an EFI bootloader"
    return 0
fi


### Copy syslinux files into the staging directory

LogPrint "Using syslinux to create an EFI bootloader"

RAWDISK_BOOT_EFI_STAGING_ROOT="$TMP_DIR/EFI"
RAWDISK_BOOT_USING_SYSLINUX="true"
local efi_boot_directory="$RAWDISK_BOOT_EFI_STAGING_ROOT/BOOT"

mkdir $v -p "$efi_boot_directory" || Error "Could not create $efi_boot_directory"

cp $v "$syslinux_efi" "$efi_boot_directory/BOOTX64.EFI" >&2
cp $v "$ldlinux_e64" "$efi_boot_directory" >&2


# Note: 280_create_bootable_disk_image.sh will install a syslinux configuration
# which will be shared between syslinux/EFI and syslinux/Legacy bootloaders.
