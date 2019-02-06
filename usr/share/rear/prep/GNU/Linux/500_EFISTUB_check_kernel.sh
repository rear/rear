is_true $EFI_STUB || return 0

# Despite user made his choice, check if kernel can really boot with EFISTUB.
grep -q -i "EFI stub" $KERNEL_FILE || Error "$KERNEL_FILE is not compiled with EFISTUB support"
Log "EFI_STUB: Using kernel $KERNEL_FILE with EFISTUB support"

Log "EFI_STUB: Checking if Kernel file: $KERNEL_FILE is hosted on vfat filesystem"
esp_mountpoint=$( df -P "${KERNEL_FILE}" | tail -1 | awk '{print $6}' )
uefi_fs_type=$(df -T "$esp_mountpoint" | tail -n +2 | head -n 1 | awk '{print $2}')

[[ "$uefi_fs_type" != "vfat" ]] && Error "EFI_STUB: Kernel file: $KERNEL_FILE is not hosted on vfat filesystem"
Log "EFI_STUB: Kernel file: $KERNEL_FILE is hosted on vfat filesystem"

local info_file=$VAR_DIR/layout/config/EFI_STUB_info.txt

# Save kernel location and options for `rear recover' phase.
# During recover mount point holding kernel will be considered ESP,
# and these information will be later used for efibootmgr.
Log "EFI_STUB: Saving information for later use"
echo $KERNEL_FILE > $info_file

# Save boot parameters from current boot.
# If EFI_STUB_EFIBOOTMGR_ARGS is not set by user, we will later use them.
cat /proc/cmdline >> $info_file
