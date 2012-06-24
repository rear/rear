# 80_create_isofs.sh
#
# create initramfs for Relax-and-Recover
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

# check that we have mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executable !"

ISO_FILES=( ${ISO_FILES[@]} boot/boot.img )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

# move $TMP_DIR/boot.img to $TMP_DIR/isofs/boot
mkdir -p $v "$TMP_DIR/isofs" >&2
mkdir -p $v "$TMP_DIR/isofs/boot" >&2
mv -f $v $TMP_DIR/boot.img "$TMP_DIR/isofs/boot" >&2
pushd $TMP_DIR/isofs >&8 # so that relative paths will work
$ISO_MKISOFS_BIN $v -o "$ISO_DIR/$ISO_PREFIX.iso" -b boot/boot.img -c boot/boot.catalog \
	-no-emul-boot -R -T -J -volid "$ISO_VOLID" -v . >&8
StopIfError "Could not create ISO image"

ISO_IMAGES=( "${ISO_IMAGES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
