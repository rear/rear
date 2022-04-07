# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
test -x "$ISO_MKISOFS_BIN" || Error "No executable ISO_MKISOFS_BIN '$ISO_MKISOFS_BIN'"

# kernel and initrd are already included in virtual image of ISO if ebiso is used
if [[ $(basename $ISO_MKISOFS_BIN) = "ebiso" && $(basename ${UEFI_BOOTLOADER}) = "elilo.efi" ]]; then
    Log "ebiso is used where kernel and initrd are already included in virtual image of ISO, skipping copying kernel and initrd"
else
    Log "Copying kernel and initrd"
    cp -pL $v $KERNEL_FILE $TMP_DIR/isofs/isolinux/kernel || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
    cp $v $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/isofs/isolinux/$REAR_INITRD_FILENAME || Error "Failed to copy initrd '$REAR_INITRD_FILENAME'"
fi

#ISO_FILES+=( $TMP_DIR/kernel $TMP_DIR/$REAR_INITRD_FILENAME )
# in case the user populates this array manually we must not forget to copy
# these files to our temporary isofs
if test "${#ISO_FILES[@]}" -gt 0 ; then
    cp -pL $v "${ISO_FILES[@]}" $TMP_DIR/isofs/isolinux/ || Error "Failed to copy ISO_FILES ${ISO_FILES[*]}"
fi

mkdir -p $v "$ISO_DIR" || Error "Failed to create ISO_DIR '$ISO_DIR'"

