# 200_mount_bootimg.sh
dd if=/dev/zero of=$TMP_DIR/boot.img count=64000 bs=1024
# make sure we select FAT16 instead of FAT12 as size >30MB
mkfs.vfat $v -F 16 $TMP_DIR/boot.img
mkdir -p $v $TMP_DIR/mnt
# Do not specify '-o fat=16' when loop mounting boot.img file
# but rely on the automatic FAT type detection when mounting
# cf. https://github.com/rear/rear/issues/2575
mount $v -o loop -t vfat $TMP_DIR/boot.img $TMP_DIR/mnt || Error "Failed to loop mount boot.img"
