# #80_copy_to_tftp.sh
#
# copy kernel and initrd to TFTP server for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

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
