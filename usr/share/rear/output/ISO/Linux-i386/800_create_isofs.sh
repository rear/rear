# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executable !"

# kernel and initrd are already included in virtual image of ISO if ebiso is used
if [[ $(basename $ISO_MKISOFS_BIN) = "ebiso" && $(basename ${UEFI_BOOTLOADER}) = "elilo.efi" ]]; then
   Log "Kernel is already present in virtual image, skipping"
else
   Log "Copying kernel and initrd"
   cp -pL $v $KERNEL_FILE $TMP_DIR/isofs/isolinux/kernel >&2
   cp $v $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/isofs/isolinux/$REAR_INITRD_FILENAME >&2
fi

#ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/kernel $TMP_DIR/$REAR_INITRD_FILENAME )
# in case the user populates this array manually we must not forget to copy
# these files to our temporary isofs
if test "${#ISO_FILES[@]}" -gt 0 ; then
    cp -pL $v ${ISO_FILES[@]}  $TMP_DIR/isofs/isolinux/ >&2
fi

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

