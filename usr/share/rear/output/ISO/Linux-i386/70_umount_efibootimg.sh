# 90_umount_bootimg.sh
(( USING_UEFI_BOOTLOADER )) || return    # empty or 0 means NO UEFI
umount $v $TMP_DIR/efiboot.img >&2
#mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/boot/efiboot.img >&2
mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/isofs/boot/efiboot.img >&2
StopIfError "Could not move efiboot.img file"

#ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/boot/efiboot.img )
