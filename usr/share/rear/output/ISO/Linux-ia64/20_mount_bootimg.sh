# 20_mount_bootimg.sh
dd if=/dev/zero of="$BUILD_DIR"/tmp/boot.img count=32000 bs=1024
mkfs $v -t vfat "$BUILD_DIR"/tmp/boot.img
mkdir -p $v "$BUILD_DIR"/mnt
mount $v -o loop -t vfat "$BUILD_DIR"/tmp/boot.img "$BUILD_DIR"/mnt
