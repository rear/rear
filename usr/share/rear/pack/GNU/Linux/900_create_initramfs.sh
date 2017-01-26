# 900_create_initramfs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LogPrint "Creating recovery/rescue system initramfs/initrd"

pushd "$ROOTFS_DIR" >/dev/null
# First try to create initrd.xz with the newer xz-lzma compression,
# see https://github.com/rear/rear/issues/1142
# The REAR_INITRD_FILENAME is needed in various subsequent scripts:
REAR_INITRD_FILENAME="initrd.xz"
if find . ! -name "*~" | cpio -H newc --create --quiet | xz --format=lzma --compress --stdout > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
    LogPrint "Created $REAR_INITRD_FILENAME with xz-lzma compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
else
    REAR_INITRD_FILENAME="initrd.cgz"
    # If it fails to create initrd.xz with xz-lzma compression
    # fall back to the traditional way and create initrd.cgz with gzip compression,
    # cf. "Dirty hacks welcome" at https://github.com/rear/rear/wiki/Coding-Style
    if find . ! -name "*~" | cpio -H newc --create --quiet | gzip > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
        LogPrint "Created $REAR_INITRD_FILENAME with gzip compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes)"
    else
        # No need to clean up things (like 'popd') because Error exits directly:
        Error "Failed to create recovery/rescue system initramfs/initrd"
    fi
fi
popd >/dev/null

