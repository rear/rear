is_true $EFI_STUB || return 0

# If USING_UEFI_BOOTLOADER is not set until this stage, we will imply
# "true" value, otherwise we will respect current value.
# We will even respect if user set (for whatever reason) USING_UEFI_BOOTLOADER=0 (false).
test -z $USING_UEFI_BOOTLOADER && USING_UEFI_BOOTLOADER=1

# It does not make any sense to trying EFISTUB without EFI boot enabled.
is_true $USING_UEFI_BOOTLOADER || Error "EFI_STUB: EFI checks failed, try to set USING_UEFI_BOOTLOADER=y"
