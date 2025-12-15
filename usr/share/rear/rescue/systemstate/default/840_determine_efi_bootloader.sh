#
# Determine current EFI bootloader
#

if ! is_true "$USING_UEFI_BOOTLOADER"; then
    return 0
fi

if is_true "$EFI_STUB"; then
    return 0
fi

if [ -f "$UEFI_BOOTLOADER" ] && ! efi_sb_enabled; then
    return 0
fi

if ! EFI_BOOTLOADER_PATH=$(efi_get_current_full_bootloader_path); then
    return 0
fi

SECURE_BOOT_BOOTLOADER="$EFI_BOOTLOADER_PATH"
