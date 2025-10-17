#
# Check that firmware type is the same on the source and target systems
#

local target_firmware_type="BIOS"
if [ -d "/sys/firmware/efi/vars" ] || [ -d "/sys/firmware/efi/efivars" ] ; then
    target_firmware_type="EFI"
fi

local source_firmware_type="BIOS"
if is_true "$USING_UEFI_BOOTLOADER"; then
    source_firmware_type="EFI"
fi

text="Firmware type mismatch detected. The source system firmware type is ${source_firmware_type}, \
while the target system firmware type is ${target_firmware_type}. Mismatched firmware types are not allowed. \
Please reconfigure your target system to use ${source_firmware_type}."

if [ "$source_firmware_type" != "$target_firmware_type" ] ; then
    cove_print_in_frame "ERROR" "$text"
    Error "Firmware type mismatch detected."
fi
