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

# We add 2 more 32MiB blocks to be on the safe side against inexplicable failures like
# "cp: error writing '/tmp/rear.XXX/tmp/efi_virt/./EFI/BOOT/...': No space left on device"
# where the above calculated $efi_img_sz is a bit too small in practice
# cf. https://github.com/rear/rear/issues/2552
(( efi_img_sz += 2 ))

# Prepare EFI virtual image aligned to 32MiB blocks:
dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$efi_img_sz bs=32M

# Make a FAT filesystem on the efiboot.img file and loop mount it
# cf. https://github.com/rear/rear/issues/2575
# See output/RAWDISK/Linux-i386/280_create_bootable_disk_image.sh
# Having a small EFI System Partition (ESP) might introduce problems:
# - The UEFI spec seems to require a FAT32 EFI System Partition (ESP).
# - syslinux/Legacy BIOS fails to install on small FAT32 partitions with "syslinux: zero FAT sectors (FAT12/16)".
# - Some firmwares fail to boot from small FAT32 partitions.
# - Some firmwares fail to boot from FAT16 partitions.
# See:
# - http://www.rodsbooks.com/efi-bootloaders/principles.html
# - http://lists.openembedded.org/pipermail/openembedded-core/2012-January/055999.html
# Let mkfs.vfat automatically select the FAT type based on the size.
# See what "man mkfs.vfat" reads for the '-F' option:
#  "If nothing is specified, mkfs.fat will automatically select
#   between 12, 16 and 32 bit, whatever fits better for the filesystem size"
# I.e. do not use a '-F 16' or '-F 32' option and hope for the best:
mkfs.vfat $v $TMP_DIR/efiboot.img
mkdir -p $v $TMP_DIR/efi_virt
# Do not specify '-o fat=16' or '-o fat=32' when loop mounting the efiboot.img FAT file
# but rely on the automatic FAT type detection (see what "man 8 mount" reads for 'fat=...'):
mount $v -o loop -t vfat $TMP_DIR/efiboot.img $TMP_DIR/efi_virt || Error "Failed to loop mount efiboot.img"

# Copy files from staging directory into efiboot.img
cp $v -r $TMP_DIR/mnt/. $TMP_DIR/efi_virt

# Umounting the EFI virtual image:
local what_is_mounted="EFI virtual image $TMP_DIR/efiboot.img at $TMP_DIR/efi_virt"
if ! umount $v $TMP_DIR/efiboot.img ; then
    # Normal umounting something directly after some I/O command (like 'cp' above)
    # may sometimes fail with "target is busy" (cf. 'busy' and 'lazy' in "man umount")
    # so we retry after one second to increase likelihood that it then succeeds
    # because normal umount is preferred over more sophisticated attempts
    # like lazy or enforced umount which raise their own specific troubles:
    Log "Failed to umount $what_is_mounted (will retry after one second)"
    sleep 1
    if ! umount $v $TMP_DIR/efiboot.img ; then
        Log "Again failed to umount $what_is_mounted"
        Log "$what_is_mounted is still in use by ('kernel mount' is always there)"
        fuser -v -m $TMP_DIR/efi_virt 1>&2
        DebugPrint "Trying 'umount --lazy $TMP_DIR/efiboot.img' (normal umount failed)"
        # Do only plain 'umount --lazy' without additional '--force'
        # so we don't use the umount_mountpoint_lazy() function here:
        if ! umount $v --lazy $TMP_DIR/efiboot.img ; then
            # When umounting the EFI virtual image fails it is no hard error so only inform the user
            # so he can understand why later cleanup_build_area_and_end_program() may show
            # "Could not remove build area" (when lazy umount could not clean up things until then)
            # cf. https://github.com/rear/rear/issues/2908
            LogPrintError "Could not umount $what_is_mounted"
        fi
    fi
fi

# Move efiboot.img into ISO directory:
mv $v -f $TMP_DIR/efiboot.img $TMP_DIR/isofs/boot/efiboot.img || Error "Failed to move efiboot.img to isofs/boot/efiboot.img"
