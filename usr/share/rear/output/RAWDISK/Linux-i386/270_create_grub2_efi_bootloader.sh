# Use Grub 2 to create an EFI bootloader
#


### Check prerequisites

# Run only if no EFI bootloader has been created yet and Grub 2 EFI is available
([[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] || ! has_binary grub-mkimage || ! [[ -d /usr/lib/grub/x86_64-efi ]]) && return 0

if is_true "${RAWDISK_BOOT_EXCLUDE_GRUB2_EFI:-no}"; then
    LogPrint "DISABLED: Using Grub 2 to create an EFI bootloader"
    return 0
fi


### Copy Grub 2 files into the staging directory

LogPrint "Using Grub 2 to create an EFI bootloader"

if is_true $USING_UEFI_BOOTLOADER ; then
    LogPrint "TIP: You can achieve a faster EFI boot by installing syslinux for EFI on this system"
fi

RAWDISK_BOOT_EFI_STAGING_ROOT="$TMP_DIR/EFI"
local efi_boot_directory="$RAWDISK_BOOT_EFI_STAGING_ROOT/BOOT"

mkdir $v -p "$efi_boot_directory"
StopIfError "Could not create $efi_boot_directory"

# Create a Grub 2 configuration file
cat > "$efi_boot_directory/grub.cfg" << EOF
set timeout=0
set default=0
menuentry "${RAWDISK_BOOT_GRUB_MENUENTRY_TITLE:-Rescue System}" {
    linux /$(basename "$KERNEL_FILE") $KERNEL_CMDLINE
    initrd /$REAR_INITRD_FILENAME
}
EOF

# Create a Grub 2 EFI core image
local grub_modules=( part_gpt fat normal configfile linux video all_video )
grub-mkimage -O x86_64-efi -o "$efi_boot_directory/BOOTX64.efi" -p "/EFI/BOOT" "${grub_modules[@]}"
StopIfError "Error occurred during grub-mkimage of $efi_boot_directory/BOOTX64.efi"
