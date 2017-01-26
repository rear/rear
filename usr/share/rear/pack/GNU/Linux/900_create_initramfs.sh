# 900_create_initramfs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The REAR_INITRD_FILENAME is needed in various subsequent scripts that install the bootloader
# of the Relax-and-Recover recovery/rescue system during the subsequent 'output' stage.
pushd "$ROOTFS_DIR" >/dev/null
case "$REAR_INITRD_COMPRESSION" in
    (lzma)
        # Create initrd.xz with xz and use the lzma compression, see https://github.com/rear/rear/issues/1142
        REAR_INITRD_FILENAME="initrd.xz"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with xz lzma compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | xz --format=lzma --compress --stdout > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            LogPrint "Created $REAR_INITRD_FILENAME with xz lzma compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (fast)
        # Create initrd.cgz with gzip --fast compression (fast speed but less compression)
        REAR_INITRD_FILENAME="initrd.cgz"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip fast compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip --fast > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            LogPrint "Created $REAR_INITRD_FILENAME with gzip fast compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (best)
        # Create initrd.cgz with gzip --best compression (best compression but slow speed)
        REAR_INITRD_FILENAME="initrd.cgz"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip best compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip --best > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            LogPrint "Created $REAR_INITRD_FILENAME with gzip best compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (*)
        # Create initrd.cgz with gzip default compression by default and also as fallback
        # (no need to error out here if REAR_INITRD_COMPRESSION has an invalid value)
        REAR_INITRD_FILENAME="initrd.cgz"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip default compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            LogPrint "Created $REAR_INITRD_FILENAME with gzip default compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
esac
popd >/dev/null

