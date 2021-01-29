# 700_create_efibootimg.sh
is_true $USING_UEFI_BOOTLOADER || return 0 # empty or 0 means NO UEFI

# Calculate exact size of EFI virtual image (efiboot.img):
# Get size of directory holding EFI virtual image content.
# The virtual image must be aligned to 32MiB blocks
# therefore the size of directory is measured in 32MiB blocks.
# The du output is stored in an artificial bash array
# so that $efi_img_sz can be simply used to get the first word
# which is the disk usage of the directory measured in 32MiB blocks:
efi_img_sz=( $( du --block-size=32M --summarize $TMP_DIR/mnt ) ) || Error "Failed to determine disk usage of EFI virtual image content directory."
# We add 2 more 32MiB blocks to be on the safe side against inexplicaple failures like
# "cp: error writing '/tmp/rear.XXX/tmp/efi_virt/./EFI/BOOT/elilo.conf': No space left on device"
# where the above calculated $efi_img_sz is a bit too small in practice
# cf. https://github.com/rear/rear/issues/2552
efi_img_sz=$(( efi_img_sz + 2 ))
# Prepare EFI virtual image aligned to 32MiB blocks:
dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$efi_img_sz bs=32M
mkfs.vfat $v -F 16 $TMP_DIR/efiboot.img >&2
mkdir -p $v $TMP_DIR/efi_virt >&2
mount $v -o loop -t vfat -o fat=16 $TMP_DIR/efiboot.img $TMP_DIR/efi_virt >&2

# copy files from staging directory
cp $v -r $TMP_DIR/mnt/. $TMP_DIR/efi_virt

umount $v $TMP_DIR/efiboot.img >&2
mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/isofs/boot/efiboot.img >&2
StopIfError "Could not move efiboot.img file"
