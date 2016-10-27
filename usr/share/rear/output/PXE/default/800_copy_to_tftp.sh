# 80_copy_to_tftp.sh
#
# copy kernel and initrd to TFTP server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# TODO: mount remote TFTP path
PXE_TFTP_LOCAL_PATH="$PXE_TFTP_PATH"
PXE_KERNEL="${PXE_TFTP_PREFIX}kernel"
PXE_INITRD="${PXE_TFTP_PREFIX}initrd.cgz"
PXE_MESSAGE="${PXE_TFTP_PREFIX}message"

[[ ! -d "$PXE_TFTP_LOCAL_PATH" ]] && mkdir $v -m 750 "$PXE_TFTP_LOCAL_PATH" >&2

cp -pL $v "$KERNEL_FILE" "$PXE_TFTP_LOCAL_PATH/$PXE_KERNEL" >&2
cp -a $v "$TMP_DIR"/initrd.cgz "$PXE_TFTP_LOCAL_PATH/$PXE_INITRD" >&2

echo "$VERSION_INFO" >"$PXE_TFTP_LOCAL_PATH/$PXE_MESSAGE"

# TODO: umount remote TFTP path

LogPrint "Copied kernel+initrd ($(du -shc $KERNEL_FILE "$TMP_DIR/initrd.cgz" | tail -n 1 | tr -s "\t " " " | cut -d " " -f 1 )) to $PXE_TFTP_PATH"

# Add to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$PXE_TFTP_LOCAL_PATH/$PXE_KERNEL" "$PXE_TFTP_LOCAL_PATH/$PXE_INITRD" "$PXE_TFTP_LOCAL_PATH/$PXE_MESSAGE" )
