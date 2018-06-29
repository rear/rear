# 800_create_isofs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# check that we have mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executable !"

ISO_FILES=( ${ISO_FILES[@]} boot/boot.img )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

# move $TMP_DIR/boot.img to $TMP_DIR/isofs/boot
mkdir -p $v "$TMP_DIR/isofs" >&2
mkdir -p $v "$TMP_DIR/isofs/boot" >&2
mv -f $v $TMP_DIR/boot.img "$TMP_DIR/isofs/boot" >&2

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TMP_DIR/isofs >&2 # so that relative paths will work

$ISO_MKISOFS_BIN $v -o "$ISO_DIR/$ISO_PREFIX.iso" -b boot/boot.img -c boot/boot.catalog \
	-no-emul-boot -R -T -J -volid "$ISO_VOLID" -v . >/dev/null
StopIfError "Could not create ISO image"

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )

popd >&2

