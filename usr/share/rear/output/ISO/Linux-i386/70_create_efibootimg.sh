# 70_create_efibootimg.sh
is_true $USING_UEFI_BOOTLOADER || return    # empty or 0 means NO UEFI

# function to calculate exact size of EFI virtual image (efiboot.img)
function efiboot_img_size {
    # Get size of directory holding EFI virtual image content.
    # The virtual image must be aligned to 32MiB blocks
    # therefore the size of directory is measured in 32MiB blocks.
    efi_img_dir=$1
    
    # Specify a minimum EFI virtual image size measured in 32MiB blocks:
    case "$( basename $UEFI_BOOTLOADER )" in
        (shim.efi|elilo.efi)
            # minimum EFI virtual image size for shim and elilo
            # default: 128MiB = 4 * 32MiB blocks
            efi_img_min_sz=4
        ;;
        (*)
            # minimum EFI virtual image size for grub
            # default: 32MiB = 1 * 32MiB block
            efi_img_min_sz=1
        ;;
    esac
    
    # Fallback output of the minimum EFI virtual image size measured in 32MiB blocks:
    test $efi_img_dir || echo $efi_img_min_sz
    
    # The du output is stored in an artificial bash array
    # so that $efi_img_sz can be simply used to get the first word
    # which is the efi_img_sz value measured in 32MiB blocks:
    efi_img_sz=( $( du --block-size=32M --summarize $efi_img_dir ) )
    
    # Fallback output of the minimum EFI virtual image size measured in 32MiB blocks:
    test $efi_img_sz || echo $efi_img_min_sz
    test $efi_img_sz -ge 1 || echo $efi_img_min_sz
    
    # Output at least the minimum EFI virtual image size measured in 32MiB blocks:
    if test $efi_img_sz -lt $efi_img_min_sz ; then
        echo $efi_img_min_sz
    else
        echo $efi_img_sz
    fi
}

# prepare EFI virtual image
dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$( efiboot_img_size $TMP_DIR/mnt ) bs=32M
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
