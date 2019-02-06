# 260_populate_efistub.sh

# Skip if no UEFI is used:
is_true $USING_UEFI_BOOTLOADER || return 0

# Skip if EFISTUB is not used
is_true $EFI_STUB || return 0

local efi_boot_tmp_dir="$TMP_DIR/mnt/EFI/BOOT"
mkdir $v -p $efi_boot_tmp_dir || Error "Could not create $efi_boot_tmp_dir"

# For EFI_STUB=true, we will use systemd-bootx64.efi shipped with Systemd
# as a default.
# systemd-bootx64.efi is used only for ReaR rescue system (to display boot menu)
# and does not take part neither in restore nor in booting of restored system.
# In theory we don't need to have any boot loader for ReaR rescue system,
# since kernel can be loaded directly by UEFI, but not everyone is familiar
# or comfortable with EFI shell.

Log "EFI_STUB: will use $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER as ReaR rescue system boot loader"

# Do some basic checks that OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER exists
# and is EFI application. Should checks fail, abort operation with error.
# Check if file exists.
if [[ -f $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER ]]; then
    # Check magic number of EFI application.
    if [[ $(file $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER | grep -E "EFI application|MS Windows") ]]; then
        Log "EFI_STUB: $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER looks to be valid EFI executable"
    else
        Error "EFI_STUB: $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER is not valid EFI executable"
    fi
else
    Error "EFI_STUB: EFI executable $OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER not found"
fi

cp $v "$OUTPUT_EFISTUB_SYSTEMD_BOOTLOADER" $efi_boot_tmp_dir/BOOTX64.efi


# Create boot menu entries for systemd-bootx64.efi.
mkdir $v -p -m 755 $TMP_DIR/isofs/loader/entries
cat > $TMP_DIR/isofs/loader/loader.conf << EOF
default  rear
timeout  10
EOF

cat > $TMP_DIR/isofs/loader/entries/rear.conf << EOF
title   $PRODUCT v$VERSION - Recover $HOSTNAME
linux   /isolinux/kernel
initrd  /isolinux/initrd.cgz
options root=/dev/ram0 $KERNEL_CMDLINE
EOF

# Copy of efiboot content also the our ISO tree (isofs/)
mkdir $v -p -m 755 $TMP_DIR/isofs/EFI/BOOT $TMP_DIR/isofs/boot
cp $v -r $TMP_DIR/mnt/EFI $TMP_DIR/isofs/ || Error "Could not create the isofs/EFI/BOOT directory on the ISO image"
