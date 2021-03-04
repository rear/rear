# 200_mount_bootimg.sh
dd if=/dev/zero of=$TMP_DIR/boot.img count=64000 bs=1024
# Make a FAT filesystem on the boot.img file and loop mount it
# cf. https://github.com/rear/rear/issues/2575
# and output/ISO/Linux-i386/700_create_efibootimg.sh
# and output/RAWDISK/Linux-i386/280_create_bootable_disk_image.sh
# Let mkfs.vfat automatically select the FAT type based on the size.
# I.e. do not use a '-F 16' or '-F 32' option and hope for the best:
mkfs.vfat $v $TMP_DIR/boot.img
mkdir -p $v $TMP_DIR/mnt
mount $v -o loop -t vfat $TMP_DIR/boot.img $TMP_DIR/mnt || Error "Failed to loop mount boot.img"
