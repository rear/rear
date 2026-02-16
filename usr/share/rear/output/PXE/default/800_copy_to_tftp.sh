# 800_copy_to_tftp.sh
#
# copy kernel and initrd to TFTP server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

test "$PXE_TFTP_UPLOAD_URL" || Error "PXE_TFTP_UPLOAD_URL must be set for PXE output"

# E.g. PXE_TFTP_UPLOAD_URL=nfs://server/export/nfs/tftpboot
local pxe_tftp_local_path
mount_pxe_url "$PXE_TFTP_UPLOAD_URL" "pxe_tftp_local_path"

# mode must readable for others for pxe and we copy under the client HOSTNAME (=OUTPUT_PREFIX_PXE)
mkdir $v -m 755 -p "$pxe_tftp_local_path/$OUTPUT_PREFIX_PXE" || Error "Could not mkdir '$pxe_tftp_local_path/$OUTPUT_PREFIX_PXE'"
PXE_KERNEL="$OUTPUT_PREFIX_PXE/${PXE_TFTP_PREFIX}kernel"
PXE_INITRD="$OUTPUT_PREFIX_PXE/$PXE_TFTP_PREFIX$REAR_INITRD_FILENAME"

# Follow symbolic links to ensure the real content gets copied
# but do not preserve mode,ownership,timestamps (i.e. no -p option) because that may fail (on sshfs) like
# "cp: failed to preserve ownership for '/tmp/rear-efi.XXXXXXXXXX/EFI/BOOT/kernel': Operation not permitted"
cp -L $v "$KERNEL_FILE" "$pxe_tftp_local_path/$PXE_KERNEL" || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
cp -L $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$pxe_tftp_local_path/$PXE_INITRD" || Error "Failed to copy initrd '$REAR_INITRD_FILENAME'"
# files must be readable for others for PXE
# files should be writebale by owner or overwriting it on later runs will fail
chmod 644 "$pxe_tftp_local_path/$PXE_KERNEL" "$pxe_tftp_local_path/$PXE_INITRD"

LogPrint "Copied kernel+initrd $( du -shc $KERNEL_FILE "$TMP_DIR/$REAR_INITRD_FILENAME" | tail -n 1 | tr -s "\t " " " | cut -d " " -f 1 ) to $PXE_TFTP_UPLOAD_URL/$OUTPUT_PREFIX_PXE"
umount_url "$PXE_TFTP_UPLOAD_URL" "$pxe_tftp_local_path"

# vim: set et ts=4 sw=4
