#
# Check that firmware type is the same on the source and target systems
#

if [ -z "$COVE_FIRMWARE" ]; then
    return 0
fi

local source_firmware_type="$COVE_FIRMWARE"

local target_firmware_type="BIOS"
if [ -d "/sys/firmware/efi/vars" ] || [ -d "/sys/firmware/efi/efivars" ] ; then
    target_firmware_type="EFI"
fi

text="Firmware type mismatch detected. The source system firmware type is ${source_firmware_type}, \
while the target system firmware type is ${target_firmware_type}. Mismatched firmware types are not allowed. \
Please reconfigure your target system to use ${source_firmware_type}."

if [ "$source_firmware_type" != "$target_firmware_type" ] ; then
    cove_print_in_frame "ERROR" "$text"
    Error "Firmware type mismatch detected."
fi
