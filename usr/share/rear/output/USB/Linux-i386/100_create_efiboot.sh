is_true $USING_UEFI_BOOTLOADER || return

# 100_create_efiboot.sh
# USB device needs to be formated with command `rear format -- --efi /dev/<device_name>'

Log "Configuring device for EFI boot"

# $BUILD_DIR is not present at this stage, temp dir will be used instead
EFI_MPT=$(mktemp -d /tmp/rear-efi.XXXXX)
StopIfError "Failed to create mount point ${EFI_MPT}"

uefi_bootloader_basename=$( basename "$UEFI_BOOTLOADER" )
EFI_PART="/dev/disk/by-label/REAR-EFI"
EFI_DIR="/EFI/BOOT"
EFI_DST="${EFI_MPT}/${EFI_DIR}"

# Fail if EFI partition is not present
if [[ ! -b ${EFI_PART} ]]; then
    Error "${EFI_PART} is not block device. Use \`rear format -- --efi <USB_device_file>' for correct format"
fi

# Mount EFI partition
mount ${EFI_PART} ${EFI_MPT}
StopIfError "Failed to mount EFI partition ${EFI_PART} to ${EFI_MPT}"

# Create EFI friendly dir structure
mkdir -p ${EFI_DST}
StopIfError "Failed to create ${EFI_DST}"

# Copy boot loader
cp $v ${UEFI_BOOTLOADER} "${EFI_DST}/BOOTX64.efi"
StopIfError "Could not copy EFI bootloader to ${EFI_DST}/BOOTX64.efi"

# Copy kernel
cp -pL $v "${KERNEL_FILE}" "${EFI_MPT}/kernel" >&2
StopIfError "Could not copy ${KERNEL_FILE} to ${EFI_MPT}/kernel"

# Copy intel microcode updater when the file exists
local initrd_intel_ucode_img
if [[ -f /boot/intel-ucode.img ]]; then
    cp -pL $v /boot/intel-ucode.img "${EFI_MPT}/intel-ucode.img" >&2
    StopIfError "Could not copy /boot/intel-ucode.img to ${EFI_MPT}/intel-ucode.img"
    initrd_intel_ucode_img="initrd /intel-ucode.img"
else
    initrd_intel_ucode_img=""
fi

# Copy initrd
cp -p $v "${TMP_DIR}/$REAR_INITRD_FILENAME" "${EFI_MPT}/$REAR_INITRD_FILENAME" >&2
StopIfError "Could not copy ${TMP_DIR}/$REAR_INITRD_FILENAME to ${EFI_MPT}/$REAR_INITRD_FILENAME"

Log "Copied kernel and $REAR_INITRD_FILENAME to ${EFI_MPT}"

# Configure systemd-boot for EFI boot
if [[ "$uefi_bootloader_basename" == "systemd-bootx64.efi" ]]; then
    Log "Configuring systemd-boot for EFI boot"

    # Create folder to store config files
    mkdir "${EFI_MPT}/loader"
    # Create main config for systemd-boot
    cat > ${EFI_MPT}/loader/loader.conf << EOF
default rear
editor 1
timeout 5
EOF
    # Create folder to store individual entries their configuration file
    mkdir "${EFI_MPT}/loader/entries"
    # Create entry config file
    # Labels are copied from elilo example below
    # FIXME: not sure whether $KERNEL_CMDLINE should be appended.
    # In that case, before EOF the line below could be inserted.
    # options $KERNEL_CMDLINE
    cat > ${EFI_MPT}/loader/entries/rear.conf << EOF
title rear
linux /kernel
$initrd_intel_ucode_img
initrd /$REAR_INITRD_FILENAME
EOF
# Configure elilo for EFI boot
elif test "$uefi_bootloader_basename" = "elilo.efi" ; then
    Log "Configuring elilo for EFI boot"

    # Create config for elilo
    Log "Creating ${EFI_DST}/elilo.conf"

    cat > ${EFI_DST}/elilo.conf << EOF
default = rear
timeout = 5

image = kernel
    label = rear
    initrd = $REAR_INITRD_FILENAME
EOF

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
    kernel ${EFI_DIR}/kernel
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
    linux ${EFI_DIR}/kernel
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

# If efibootmgr is available, configure the UEFI boot menu for EFISTUB booting
# Note: adding a new entry might change the boot order. Make sure the boot order will be unchanged.
#Log "Adding rear as item to the UEFI boot menu."
# This will fail because efibootmgr version 15 does not have USB device support.

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
