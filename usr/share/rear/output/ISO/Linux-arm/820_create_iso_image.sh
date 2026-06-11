# Based on output/ISO/Linux-i386/820_create_iso_image.sh with the support
# for non-EFI machines removed.

is_true $EFI_STUB && return 0

Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

is_true $USING_UEFI_BOOTLOADER || Error "OUTPUT=ISO on Linux-arm works only with UEFI"
if [ -f /etc/slackware-version ] ; then
    # slackware mkisofs uses different command line options
    EFIBOOT="-eltorito-alt-boot -no-emul-boot -eltorito-platform efi -eltorito-boot boot/efiboot.img"
else
    EFIBOOT="-eltorito-alt-boot -e boot/efiboot.img -no-emul-boot"
fi

pushd $TMP_DIR/isofs >/dev/null

# Error out when files greater or equal ISO_FILE_SIZE_LIMIT should be included in the ISO (cf. default.conf).
# Consider all regular files and follow symbolic links to also get regular files where symlinks point to:
assert_ISO_FILE_SIZE_LIMIT $( find -L . -type f )

# ebiso uses different command line options and parameters:
if test "ebiso" = $( basename $ISO_MKISOFS_BIN ) ; then
    $ISO_MKISOFS_BIN $ISO_MKISOFS_OPTS -R -o $ISO_DIR/$ISO_PREFIX.iso -e boot/efiboot.img .
else
    $ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" -no-emul-boot \
        -R -J -volid "$ISO_VOLID" $EFIBOOT -v -iso-level 3 .  >/dev/null
        ##-R -J -volid "$ISO_VOLID" $EFIBOOT  "${ISO_FILES[@]}"  >/dev/null
fi
StopIfError "Could not create ISO image (with $ISO_MKISOFS_BIN)"
popd >/dev/null

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES+=( "$ISO_DIR/$ISO_PREFIX.iso" )

# vim: set et ts=4 sw=4:
