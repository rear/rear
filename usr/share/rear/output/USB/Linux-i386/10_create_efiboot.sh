# 10_create_efiboot.sh

is_true $USING_UEFI_BOOTLOADER || return
Log "Making USB devide EFI bootable"

# This supports only elilo so far, grub will follow

EFI_PART="/dev/disk/by-label/REAR-EFI"

# $BUILD_DIR is not present at this stage
# maybe use mktemp ?
EFI_MPT="/mnt/iso"

if [[ ! -d ${EFI_MPT} ]]; then
    mkdir -p ${EFI_MPT}
fi

# Mount EFI partition
mount ${EFI_PART} ${EFI_MPT}
StopIfError "Failed to mount EFI partition ${EFI_PART} to ${EFI_MPT}"

# Copy boot loader
cp $v ${UEFI_BOOTLOADER} ${EFI_MPT}
StopIfError "Failed to copy EFI bootloader"

# Copy kernel
cp -pL $v "$KERNEL_FILE" "${EFI_MPT}/kernel" >&2
StopIfError "Could not create ${EFI_MPT}/kernel"

# Copy initrd
cp -p $v "$TMP_DIR/initrd.cgz" "${EFI_MPT}/initrd.cgz" >&2
StopIfError "Could not create ${EFI_MPT}/initrd.cgz"

Log "Copied kernel and initrd.cgz to ${EFI_MPT}"

# Code for generation of elilo/grub config will be here (that will be fun part) ...

# Should we crash if umount fails?
umount ${EFI_MPT}

