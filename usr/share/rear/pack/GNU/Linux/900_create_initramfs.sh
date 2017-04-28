# 900_create_initramfs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The REAR_INITRD_FILENAME is needed in various subsequent scripts that install the bootloader
# of the Relax-and-Recover recovery/rescue system during the subsequent 'output' stage.
# REAR_INITRD_FILENAME contains the filename (i.e. basename) of ReaR's own initramfs/initrd
# that contains the files of the Relax-and-Recover recovery/rescue system.
# In contrast a variable that contains the filename of the initramfs/initrd of the system
# where "rear mkbackup" runs would have to be named like SYSTEM_INITRD_FILENAME and/or
# where "rear recover" runs like TARGET_SYSTEM_INITRD_FILENAME (cf. TARGET_FS_ROOT).
pushd "$ROOTFS_DIR" >/dev/null
start_seconds=$( date +%s )
case "$REAR_INITRD_COMPRESSION" in
    (lz4)
        # Create initrd.lz4 with lz4 default -1 compression (fast speed but less compression)
        # -l is needed to make initramfs boot, this compresses using Legacy format (Linux kernel compression)
        REAR_INITRD_FILENAME="initrd.lz4"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with lz4 compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | lz4 -l > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with lz4 compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (lzma)
        # Create initrd.xz with xz and use the lzma compression, see https://github.com/rear/rear/issues/1142
        REAR_INITRD_FILENAME="initrd.xz"
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with xz lzma compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | xz --format=lzma --compress --stdout > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with xz lzma compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
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
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip fast compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
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
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip best compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
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
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip default compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
esac
popd >/dev/null
