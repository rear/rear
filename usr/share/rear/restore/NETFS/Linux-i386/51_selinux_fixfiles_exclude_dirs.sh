# for UEFI only we should avoid SElinux relabeling vfat filesystem: /boot/efi
[[ -z "$USING_UEFI_BOOTLOADER" ]] && return  # empty means using BIOS

# check if /mnt/local/boot/efi is mounted
[[ -d "/mnt/local/boot/efi" ]]
StopIfError "Could not find directory /mnt/local/boot/efi"

cat > /mnt/local/etc/selinux/fixfiles_exclude_dirs <<EOF
/boot/efi
/boot/efi(/.*)?
EOF
