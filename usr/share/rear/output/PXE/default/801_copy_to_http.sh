# 801_copy_to_http.sh
#
# copy kernel and initrd to HTTP server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

[[ "$PXE_HTTP_UPLOAD_URL" ]] || return

# When PXE_HTTP_UPLOAD_URL equals PXE_TFTP_UPLOAD_URL then the files have
# already been uploaded by 800_copy_to_tftp.sh and we don't need to do
# anything here.
if [[ "$PXE_HTTP_UPLOAD_URL" = "$PXE_TFTP_UPLOAD_URL" ]] ; then
    Debug "PXE_HTTP_UPLOAD_URL = PXE_TFTP_UPLOAD_URL, upload already done by TFTP code in 800_copy_to_tftp.sh"
    return
fi

# E.g. PXE_HTTP_UPLOAD_URL=nfs://server/export/nfs/www
local scheme="$( url_scheme "$PXE_HTTP_UPLOAD_URL" )"

# We need filesystem access to the destination (schemes like ftp:// are not supported)
scheme_supports_filesystem $scheme || Error "Scheme $scheme from PXE_HTTP_UPLOAD_URL not supported, use a scheme that supports mounting (like nfs: )"

mount_url "$PXE_HTTP_UPLOAD_URL" "$BUILD_DIR/httpbootfs" $BACKUP_OPTIONS
# However, we copy under $OUTPUT_PREFIX_PXE directory (usually HOSTNAME) to have different clients on one pxe server
pxe_http_local_path=$BUILD_DIR/httpbootfs
# mode must readable for others for pxe and we copy under the client HOSTNAME (=OUTPUT_PREFIX_PXE)
mkdir $v -m 755 -p "$BUILD_DIR/httpbootfs/$OUTPUT_PREFIX_PXE" || Error "Could not mkdir '$BUILD_DIR/httpbootfs/$OUTPUT_PREFIX_PXE'"
PXE_KERNEL="$OUTPUT_PREFIX_PXE/${PXE_TFTP_PREFIX}kernel"
PXE_INITRD="$OUTPUT_PREFIX_PXE/$PXE_TFTP_PREFIX$REAR_INITRD_FILENAME"
PXE_MESSAGE="$OUTPUT_PREFIX_PXE/${PXE_TFTP_PREFIX}message"

# Follow symbolic links to ensure the real content gets copied
# but do not preserve mode,ownership,timestamps (i.e. no -p option) because that may fail (on sshfs) like
# "cp: failed to preserve ownership for '/tmp/rear-efi.XXXXXXXXXX/EFI/BOOT/kernel': Operation not permitted"
cp -L $v "$KERNEL_FILE" "$pxe_http_local_path/$PXE_KERNEL" || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
cp -L $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$pxe_http_local_path/$PXE_INITRD" || Error "Failed to copy initrd '$REAR_INITRD_FILENAME'"
echo "$VERSION_INFO" >"$pxe_http_local_path/$PXE_MESSAGE"
# files must be readable for others for PXE
# files should be writebale by owner or overwriting it on later runs will fail
chmod 644 "$pxe_http_local_path/$PXE_KERNEL" "$pxe_http_local_path/$PXE_INITRD" "$pxe_http_local_path/$PXE_MESSAGE"

LogPrint "Copied kernel+initrd $( du -shc $KERNEL_FILE "$TMP_DIR/$REAR_INITRD_FILENAME" | tail -n 1 | tr -s "\t " " " | cut -d " " -f 1 ) to $PXE_HTTP_UPLOAD_URL/$OUTPUT_PREFIX_PXE"
umount_url "$PXE_HTTP_UPLOAD_URL" "$BUILD_DIR/httpbootfs"

# vim: set et ts=4 sw=4
