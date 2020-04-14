
is_true $EFI_STUB && return 0

Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

if is_true $USING_UEFI_BOOTLOADER ; then
    # initialized with 1
    if [ -f /etc/slackware-version ] ; then
        # slackware mkisofs uses different command line options
        EFIBOOT="-eltorito-alt-boot -no-emul-boot -eltorito-platform efi -eltorito-boot boot/efiboot.img"
    else
        EFIBOOT="-eltorito-alt-boot -e boot/efiboot.img -no-emul-boot"
    fi
    Log "Including ISO UEFI boot (as triggered by USING_UEFI_BOOTLOADER=1)"
else
    EFIBOOT=""
fi

pushd $TMP_DIR/isofs >/dev/null
# ebiso uses different command line options and parameters:
if test "ebiso" = $( basename $ISO_MKISOFS_BIN ) ; then
    # ebiso currently works only with UEFI:
    if is_true $USING_UEFI_BOOTLOADER ; then
        $ISO_MKISOFS_BIN $ISO_MKISOFS_OPTS -R -o $ISO_DIR/$ISO_PREFIX.iso -e boot/efiboot.img .
    else
        Error "$ISO_MKISOFS_BIN works only with UEFI"
    fi
else
    $ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" \
        -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
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
