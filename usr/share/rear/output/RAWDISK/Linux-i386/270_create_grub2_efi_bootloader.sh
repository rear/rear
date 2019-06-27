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

if is_true $USING_UEFI_BOOTLOADER && [[ -z "$SECURE_BOOT_BOOTLOADER" ]]; then
    LogPrint "TIP: You can achieve a faster EFI boot by installing syslinux for EFI on this system"
fi

RAWDISK_BOOT_EFI_STAGING_ROOT="$TMP_DIR/EFI"

# Create a Grub 2 configuration file
local new_grub_config_file="$TMP_DIR/grub.cfg"
cat > "$new_grub_config_file" << EOF
set timeout=0
set default=0
menuentry "${RAWDISK_BOOT_GRUB_MENUENTRY_TITLE:-Recovery System}" {
    linux /$(basename "$KERNEL_FILE") $KERNEL_CMDLINE
    initrd /$REAR_INITRD_FILENAME
}
EOF

if [[ -n "$SECURE_BOOT_BOOTLOADER" ]]; then
    # Using Secure Boot:
    # We use '$SECURE_BOOT_BOOTLOADER' as a pointer into the original system's EFI tree, which should consist of
    # signed EFI executables (and possibly companion files). We cannot touch those signed executables without
    # breaking Secure Boot and we cannot know which companion files are actually required, so we play it safe
    # and copy the entire EFI tree as is.
    local original_efi_root="$(findmnt --noheadings --output TARGET --target "$SECURE_BOOT_BOOTLOADER")/EFI"
    LogPrint "Secure Boot: Using the original EFI configuration from '$original_efi_root'"
    cp -a $v "$original_efi_root/." "$RAWDISK_BOOT_EFI_STAGING_ROOT" || Error "Could not copy EFI configuration"

    # Now we look for existing Grub configuration files and overwrite those with our own configuration. Again, to
    # be safe, we are prepared for the situation where we might find more than one grub.cfg without knowing which
    # one is effective, so we overwrite every one.
    find "$RAWDISK_BOOT_EFI_STAGING_ROOT" -iname grub.cfg -print -exec cp $v "$new_grub_config_file" '{}' \;
    StopIfError "Could not copy Grub configuration"
else
    # Not Using Secure Boot:
    # Populate the EFI file system with a newly created Grub boot loader image and the Grub configuration file.
    local efi_boot_directory="$RAWDISK_BOOT_EFI_STAGING_ROOT/BOOT"
    mkdir $v -p "$efi_boot_directory" || Error "Could not create $efi_boot_directory"

    cp $v "$new_grub_config_file" "$efi_boot_directory/grub.cfg"

    # Create a Grub 2 EFI core image and install it as boot loader. (NOTE: This version will not be signed.)
    # Use the UEFI default boot loader name, so that firmware will find it without an existing boot entry.
    local boot_loader="$efi_boot_directory/BOOTX64.EFI"
    local grub_modules=( part_gpt fat normal configfile linux video all_video )
    grub-mkimage -O x86_64-efi -o "$boot_loader" -p "/EFI/BOOT" "${grub_modules[@]}"
    StopIfError "Error occurred during grub-mkimage of $boot_loader"
fi

rm "$new_grub_config_file"
