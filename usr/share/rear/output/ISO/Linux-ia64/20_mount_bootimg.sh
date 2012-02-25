# 20_mount_bootimg.sh
dd if=/dev/zero of=$TMP_DIR/boot.img count=64000 bs=1024
mkfs.vfat $v $TMP_DIR/boot.img >&2
mkdir -p $v $TMP_DIR/mnt >&2
mount $v -o loop -t vfat $TMP_DIR/boot.img $TMP_DIR/mnt >&2
