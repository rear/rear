# 100_create_efiboot.sh
# USB device needs to be formatted with command `rear format -- --efi /dev/<device_name>'

is_true $USING_UEFI_BOOTLOADER || return 0

Log "Configuring device for EFI boot"

# $BUILD_DIR is not present at this stage, temp dir will be used instead.
# Slackware version of mktemp requires 6 Xs in template and
# plain 'mktemp' uses XXXXXXXXXX by default (at least on SLES11 and openSUSE Leap 15.0)
# so that we comply with the 'mktemp' default to avoid 'mktemp' errors "too few X's in template":
EFI_MPT=$( mktemp -d /tmp/rear-efi.XXXXXXXXXX ) || Error "mktemp failed to create mount point '/tmp/rear-efi.XXXXXXXXXX' for EFI partition"

uefi_bootloader_basename=$( basename "$UEFI_BOOTLOADER" )
EFI_PART="/dev/disk/by-label/REAR-EFI"
EFI_DIR="/EFI/BOOT"
EFI_DST="${EFI_MPT}/${EFI_DIR}"

# Fail if EFI partition is not present
if [[ ! -b ${EFI_PART} ]]; then
    Error "${EFI_PART} is not block device. Use \`rear format -- --efi <USB_device_file>' for correct format"
fi

# Mount EFI partition
mount $EFI_PART $EFI_MPT || Error "Failed to mount EFI partition '$EFI_PART' at '$EFI_MPT'"

# Create EFI friendly dir structure
mkdir -p $EFI_DST || Error "Failed to create directory '$EFI_DST'"

# Copy boot loader
cp $v $UEFI_BOOTLOADER "$EFI_DST/BOOTX64.efi" || Error "Failed to copy UEFI_BOOTLOADER '$UEFI_BOOTLOADER' to $EFI_DST/BOOTX64.efi"

# Copy kernel
cp -pL $v "$KERNEL_FILE" "$EFI_DST/kernel" || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE' to $EFI_DST/kernel"

# Copy initrd
cp -p $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$EFI_DST/$REAR_INITRD_FILENAME" || Error "Failed to copy initrd to $EFI_DST/$REAR_INITRD_FILENAME"

Log "Copied kernel $KERNEL_FILE and initrd $REAR_INITRD_FILENAME to $EFI_DST"

# Configure elilo for EFI boot
if test "$uefi_bootloader_basename" = "elilo.efi" ; then
    Log "Configuring elilo for EFI boot"

    # Create config for elilo
    Log "Creating ${EFI_DST}/elilo.conf"

    create_ebiso_elilo_conf > ${EFI_DST}/elilo.conf

# Configure grub for EFI boot or die
else
    # Hope this assumption is not wrong ...
    if has_binary grub-install grub2-install; then

        # Choose right grub binary
        # Issue #849
        if has_binary grub2-install; then
            NUM=2
        fi

        GRUB_MKIMAGE=grub${NUM}-mkimage
        GRUB_INSTALL=grub${NUM}-install

        # What version of grub are we using
        # substr() for awk did not work as expected for this reason cut was used
        # First charecter should be enough to identify grub version
        grub_version=$($GRUB_INSTALL --version | awk '{print $NF}' | cut -c1-1)

        case ${grub_version} in
            0)
                Log "Configuring grub 0.97 for EFI boot"

                # Create config for grub 0.97
                cat > ${EFI_DST}/BOOTX64.conf << EOF
default=0
timeout=5

title Relax-and-Recover (no Secure Boot)
    kernel ${EFI_DIR}/kernel $KERNEL_CMDLINE
    initrd ${EFI_DIR}/$REAR_INITRD_FILENAME
EOF
            ;;
            2)
                Log "Configuring grub 2.0 for EFI boot"

                # Create bootloader, this overwrite BOOTX64.efi copied in previous step ...
                # Fail if BOOTX64.efi can't be created
                ${GRUB_MKIMAGE} -o ${EFI_DST}/BOOTX64.efi -p ${EFI_DIR} -O x86_64-efi linux part_gpt ext2 normal gfxterm gfxterm_background gfxterm_menu test all_video loadenv fat
                StopIfError "Failed to create BOOTX64.efi"

                # Create config for grub 2.0
                cat > ${EFI_DST}/grub.cfg << EOF
set timeout=5
set default=0

menuentry "Relax-and-Recover (no Secure Boot)" {
    linux ${EFI_DIR}/kernel $KERNEL_CMDLINE
    initrd ${EFI_DIR}/$REAR_INITRD_FILENAME
}
EOF
            ;;
            *)
                BugError "Neither grub 0.97 nor 2.0"
            ;;
        esac
    else
        BugIfError "Unknown EFI bootloader"
    fi
fi

# Do cleanup of EFI temporary mount point
Log "Doing cleanup of ${EFI_MPT}"

umount ${EFI_MPT}
if [[ $? -eq 0 ]]; then
    rmdir ${EFI_MPT}
    LogIfError "Could not remove temporary directory ${EFI_MPT}, please check manually"
else
    Log "Could not umount ${EFI_MPT}, please check manually"
fi

Log "Created EFI configuration for USB"

