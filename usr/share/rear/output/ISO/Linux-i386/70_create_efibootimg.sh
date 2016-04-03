# 70_create_efibootimg.sh
is_true $USING_UEFI_BOOTLOADER || return    # empty or 0 means NO UEFI

# prepare EFI virtual image
dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$(efiboot_img_size $TMP_DIR/mnt) bs=1M
mkfs.vfat $v -F 16 $TMP_DIR/efiboot.img >&2
mkdir -p $v $TMP_DIR/efi_virt >&2
mount $v -o loop -t vfat -o fat=16 $TMP_DIR/efiboot.img $TMP_DIR/efi_virt >&2

# copy files from staging directory
cp $v -r $TMP_DIR/mnt/. $TMP_DIR/efi_virt

umount $v $TMP_DIR/efiboot.img >&2
#mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/boot/efiboot.img >&2
mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/isofs/boot/efiboot.img >&2
StopIfError "Could not move efiboot.img file"

#ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/boot/efiboot.img )
