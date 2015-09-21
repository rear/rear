# 20_mount_efibootimg.sh
(( USING_UEFI_BOOTLOADER )) || return

# we will need more space for initrd and kernel if elilo is used
if [[ $(basename $ISO_MKISOFS_BIN) = "ebiso" && $(basename ${UEFI_BOOTLOADER}) = "elilo.efi" ]]; then
   size=128000
else
   size=32000
fi

dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$size bs=1024
# make sure we select FAT16 instead of FAT12 as size >30MB
mkfs.vfat $v -F 16 $TMP_DIR/efiboot.img >&2
mkdir -p $v $TMP_DIR/mnt >&2
mount $v -o loop -t vfat -o fat=16 $TMP_DIR/efiboot.img $TMP_DIR/mnt >&2
