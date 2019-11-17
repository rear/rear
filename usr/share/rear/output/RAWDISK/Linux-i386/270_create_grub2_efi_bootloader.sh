# Use Grub 2 to create an EFI bootloader
#


### Check prerequisites

# (1) An EFI bootloader must not have been created yet
[[ -n "$RAWDISK_BOOT_EFI_STAGING_ROOT" ]] && return 0

# (2) Grub 2 (which has a *-probe executable while Grub 1 does not) must exist
if has_binary grub-probe; then
    grub2_name="grub"  # The name prefixes executables and determines the installation directory under /boot
elif has_binary grub2-probe; then
    grub2_name="grub2"
else
    return 0
fi

# (3) Grub 2 EFI components must exist
[[ -d /usr/lib/grub/x86_64-efi ]] || return 0

# (4) Grub 2 must not have been excluded
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

# Set up contents of a Grub 2 configuration file
local new_grub_configuration
read -r -d '' new_grub_configuration << EOF
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
    [[ "$original_efi_root" == "/EFI" ]] && Error "Could not find original EFI root directory"
    LogPrint "Secure Boot: Using the original EFI configuration from '$original_efi_root'"
    cp -a $v "$original_efi_root/." "$RAWDISK_BOOT_EFI_STAGING_ROOT" || Error "Could not copy EFI configuration"

    # If /boot/$grub2_name exists, it contains additional Grub modules, which are not compiled into the grub core image.
    # Pick required ones from there, too.
    local additional_grub_directory="/boot/$grub2_name"
    local grub_modules_directory="x86_64-efi"
    local additional_grub_modules=( all_video.mod )
    if [[ -d "$additional_grub_directory/$grub_modules_directory" ]]; then
        local grub_target_directory="$(dirname "$(find "$RAWDISK_BOOT_EFI_STAGING_ROOT" -iname grubx64.efi -print)")"
        [[ "$grub_target_directory" == "." ]] && Error "Could not find Grub executable"  # dirname "" returns "."

        mkdir "$grub_target_directory/$grub_modules_directory" || Error "Could not create Grub modules directory"
        for module in "${additional_grub_modules[@]}"; do
            cp -a $v "$additional_grub_directory/$grub_modules_directory/$module" "$grub_target_directory/$grub_modules_directory"
            StopIfError "Could not copy additional Grub module '$module'"
            new_grub_configuration="insmod ${module%.mod}"$'\n'"$new_grub_configuration"
        done
    fi

    # Now we look for existing Grub configuration files and overwrite those with our own configuration. Again, to
    # be safe, we are prepared for the situation where we might find more than one grub.cfg without knowing which
    # one is effective, so we overwrite each one.
    for target_config_path in $(find "$RAWDISK_BOOT_EFI_STAGING_ROOT" -iname grub.cfg -print); do
        echo "$new_grub_configuration" > "$target_config_path"
        StopIfError "Could not copy Grub configuration to '$target_config_path'"
    done
else
    # Not Using Secure Boot:
    # Populate the EFI file system with a newly created Grub boot loader image and the Grub configuration file.
    local efi_boot_directory="$RAWDISK_BOOT_EFI_STAGING_ROOT/BOOT"
    mkdir $v -p "$efi_boot_directory" || Error "Could not create $efi_boot_directory"

    echo "$new_grub_configuration" > "$efi_boot_directory/grub.cfg"

    # Create a Grub 2 EFI core image and install it as boot loader. (NOTE: This version will not be signed.)
    # Use the UEFI default boot loader name, so that firmware will find it without an existing boot entry.
    local boot_loader="$efi_boot_directory/BOOTX64.EFI"
    local grub_modules=( part_gpt fat normal configfile linux video all_video )
    $grub2_name-mkimage -O x86_64-efi -o "$boot_loader" -p "/EFI/BOOT" "${grub_modules[@]}"
    StopIfError "Error occurred during $grub2_name-mkimage of $boot_loader"
fi
