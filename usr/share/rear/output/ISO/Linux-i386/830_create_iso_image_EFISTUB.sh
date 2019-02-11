is_true $EFI_STUB || return 0

Log "EFI_STUB: Starting '$ISO_MKISOFS_BIN'"
LogPrint "EFI_STUB: Making ISO image"

pushd $TMP_DIR/isofs >/dev/null

$ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -R -J -volid "$ISO_VOLID" -v -iso-level 3 .  >/dev/null

StopIfError "EFI_STUB: Could not create ISO image (with $ISO_MKISOFS_BIN)"
popd >/dev/null

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "EFI_STUB: Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
