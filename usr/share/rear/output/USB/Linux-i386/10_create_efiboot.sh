# 10_create_efiboot.sh
# Only elilo is supported so far, grub will follow

is_true $USING_UEFI_BOOTLOADER || return

EFI_PART="/dev/disk/by-label/REAR-EFI"

# Fail if EFI partition is not present
if [[ ! -b ${EFI_PART} ]]; then
    Error "${EFI_PART} is not block device. Use \`rear format -- --efi <USB_device_file>' for correct format"
fi

Log "Making USB devide EFI bootable"

# $BUILD_DIR is not present at this stage, temp dir will be used instead
EFI_MPT=$(mktemp -d /tmp/rear-efi.XXXXX)
StopIfError "Failed to create mountpoint ${EFI_MPT}"

# Destination for files needed by EFI
EFI_DST="${EFI_MPT}/EFI/BOOT"

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
cp -pL $v "${KERNEL_FILE}" "${EFI_DST}/kernel" >&2
StopIfError "Could not copy ${KERNEL_FILE} to ${EFI_DST}/kernel"

# Copy initrd
cp -p $v "${TMP_DIR}/initrd.cgz" "${EFI_DST}/initrd.cgz" >&2
StopIfError "Could not copy ${TMP_DIR}/initrd.cgz to ${EFI_DST}/initrd.cgz"

Log "Copied kernel and initrd.cgz to ${EFI_DST}"

# Create config for elilo
Log "Creating ${EFI_DST}/elilo.conf"

cat > ${EFI_DST}/elilo.conf << EOF
default = rear
timeout = 5

image = kernel
    label = rear
    initrd = initrd.cgz
EOF

# Do cleanup of EFI temporary mount point
Log "Doing cleanup of ${EFI_MPT}"

umount ${EFI_MPT}
if [[ $? -eq 0 ]]; then
    rmdir ${EFI_MPT}
    LogIfError "Could not remove temporary directory ${EFI_MPT}, please check manually"
else
    Log "Could not umount ${EFI_MPT}, please check manually"
fi
