# 20_mount_efibootimg.sh
(( USING_UEFI_BOOTLOADER )) || return

dd if=/dev/zero of=$TMP_DIR/efiboot.img count=32000 bs=1024
# make sure we select FAT16 instead of FAT12 as size >30MB
mkfs.vfat $v -F 16 $TMP_DIR/efiboot.img >&2
mkdir -p $v $TMP_DIR/mnt >&2
mount $v -o loop -t vfat -o fat=16 $TMP_DIR/efiboot.img $TMP_DIR/mnt >&2
