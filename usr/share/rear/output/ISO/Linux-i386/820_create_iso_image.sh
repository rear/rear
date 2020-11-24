
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

# Error out when files greater or equal ISO_FILE_SIZE_LIMIT should be included in the ISO (cf. default.conf):
is_positive_integer $ISO_FILE_SIZE_LIMIT || ISO_FILE_SIZE_LIMIT=2147483648
local file_for_iso file_for_iso_size
# Consider all regular files and follow symbolic links to also get regular files where symlinks point to:
for file_for_iso in $( find -L . -type f ) ; do
    file_for_iso_size=$( stat -L -c '%s' $file_for_iso )
    # Continue "bona fide" with testing the next one if size could not be determined (assume the current one is OK):
    is_positive_integer $file_for_iso_size || continue
    # Continue testing the next one when this one is below the file size limit:
    test $file_for_iso_size -lt $ISO_FILE_SIZE_LIMIT && continue
    Error "File for ISO $( basename $file_for_iso ) size $file_for_iso_size greater or equal ISO_FILE_SIZE_LIMIT=$ISO_FILE_SIZE_LIMIT"
done

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
