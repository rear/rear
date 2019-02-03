is_true $EFI_STUB || return 0

# If user set his own UEFI_BOOTLOADER we will end with error.
# I (@gozora) think that it is not correct to mix UEFI_BOOTLOADER with EFISTUB,
# because EFISTUB does not really use any boot loader
# (such mix of naming can become confusing over time).
# Boot loader is only a helper to auto-magically boot ReaR rescue system.

Log "EFI_STUB: Checking if UEFI_BOOTLOADER value is manually set"
test -n "$UEFI_BOOTLOADER" && Error "EFI_STUB: Manual setting of UEFI_BOOTLOADER is not supported"
