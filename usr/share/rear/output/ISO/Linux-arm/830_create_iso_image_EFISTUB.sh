# Based on output/ISO/Linux-i386/830_create_iso_image_EFISTUB.sh with the
# support for non-EFI machines removed.

is_true $EFI_STUB || return 0

Log "EFI_STUB: Starting '$ISO_MKISOFS_BIN'"
LogPrint "EFI_STUB: Making ISO image"

pushd $TMP_DIR/isofs >/dev/null

# Error out when files greater or equal ISO_FILE_SIZE_LIMIT should be included in the ISO (cf. default.conf).
# Consider all regular files and follow symbolic links to also get regular files where symlinks point to:
assert_ISO_FILE_SIZE_LIMIT $( find -L . -type f )

$ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" -no-emul-boot \
    -R -J -volid "$ISO_VOLID" -v -iso-level 3 .  >/dev/null

StopIfError "EFI_STUB: Could not create ISO image (with $ISO_MKISOFS_BIN)"
popd >/dev/null

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "EFI_STUB: Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES+=( "$ISO_DIR/$ISO_PREFIX.iso" )
