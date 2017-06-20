# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executable !"

Log "Copying kernel"
cp -pL $v $KERNEL_FILE $TMP_DIR/kernel >&2

ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/kernel $REAR_INITRD_FILENAME )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"
