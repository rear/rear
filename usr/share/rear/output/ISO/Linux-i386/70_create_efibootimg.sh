# 70_create_efibootimg.sh
is_true $USING_UEFI_BOOTLOADER || return    # empty or 0 means NO UEFI

# function to calculate exact size of EFI virtual image (efiboot.img)
function efiboot_img_size {
    # get size of directory holding EFI virtual image content
    SIZE=$(du -ms ${1} | awk '{print $1}')
    
    case "$(basename $UEFI_BOOTLOADER)" in
        (shim.efi|elilo.efi)
            # minimum EFI virtual image size for shim and elilo in [MB]
            # default: 128MB
            EFI_IMG_MIN_SZ=128
        ;;
        (*)
            # minimum EFI virtual image size for grub in [MB]
            # default: 32MB
            EFI_IMG_MIN_SZ=32
        ;;
    esac
    
    if [ ${SIZE} -lt ${EFI_IMG_MIN_SZ} ]; then
        FINAL_SIZE=${EFI_IMG_MIN_SZ}
    else
        FINAL_SIZE=${SIZE}
    fi
       
    # final size must be aligned to 32
    # +1 to add some buffer space when going marginal    
    echo $(((FINAL_SIZE / 32 + 1) * 32))
}

# prepare EFI virtual image
dd if=/dev/zero of=$TMP_DIR/efiboot.img count=$(efiboot_img_size $TMP_DIR/mnt) bs=1M
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
