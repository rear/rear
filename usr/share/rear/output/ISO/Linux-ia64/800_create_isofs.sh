# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executable !"

ISO_FILES+=( boot/boot.img )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR"
StopIfError "Could not create ISO output directory ($ISO_DIR)"

# move $TMP_DIR/boot.img to $TMP_DIR/isofs/boot
mkdir -p $v "$TMP_DIR/isofs"
mkdir -p $v "$TMP_DIR/isofs/boot"
mv -f $v $TMP_DIR/boot.img "$TMP_DIR/isofs/boot"

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TMP_DIR/isofs # so that relative paths will work

# Error out when files greater or equal ISO_FILE_SIZE_LIMIT should be included in the ISO (cf. default.conf).
# Consider all regular files and follow symbolic links to also get regular files where symlinks point to:
assert_ISO_FILE_SIZE_LIMIT $( find -L . -type f )

$ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" \
    -b boot/boot.img -c boot/boot.catalog \
    -no-emul-boot -R -T -J -volid "$ISO_VOLID" -v . >/dev/null
StopIfError "Could not create ISO image"

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES+=( "$ISO_DIR/$ISO_PREFIX.iso" )

popd

# vim: set et ts=4 sw=4:
