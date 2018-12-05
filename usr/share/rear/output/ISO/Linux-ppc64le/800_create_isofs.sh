# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
test -x "$ISO_MKISOFS_BIN" || Error "No executable ISO_MKISOFS_BIN '$ISO_MKISOFS_BIN'"

Log "Copying kernel"
cp -pL $v $KERNEL_FILE $TMP_DIR/kernel || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"

test -s "$TMP_DIR/$REAR_INITRD_FILENAME" || Error "No initrd '$TMP_DIR/$REAR_INITRD_FILENAME'"

ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/kernel $TMP_DIR/$REAR_INITRD_FILENAME )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" || Error "Failed to create ISO_DIR '$ISO_DIR'"

