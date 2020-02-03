# USING_UEFI_BOOTLOADER empty or no explicit 'true' value means NO UEFI:
is_true $USING_UEFI_BOOTLOADER || return 0

# Don't do any guess work for boot loader, we will use systemd-bootx64.efi.
is_true $EFI_STUB && return 0

esp_info=$(df $UEFI_BOOTLOADER | tail -n 1)
esp_mpt=$(echo $esp_info | awk '{print $NF}')
esp_disk=$(echo $esp_info | awk '{print $1}')
esp_relative_bootloader=$(echo ${UEFI_BOOTLOADER#$esp_mpt})
esp_disk_uuid=$(echo $(lsblk --noheadings --output uuid $esp_disk))
