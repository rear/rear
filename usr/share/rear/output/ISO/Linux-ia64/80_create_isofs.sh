# 80_create_isofs.sh
#
# create initramfs for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

# last check for mkisofs
[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN] not an executabel !"

ISO_FILES=( ${ISO_FILES[@]} boot/boot.img )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

# move "$BUILD_DIR"/tmp/boot.img to $BUILD_DIR/isofs/boot
mkdir -p $v "$BUILD_DIR/isofs" >&2
mkdir -p $v "$BUILD_DIR/isofs/boot" >&2
mv -f $v "$BUILD_DIR"/tmp/boot.img "$BUILD_DIR/isofs/boot" >&2
pushd $BUILD_DIR/isofs >&8 # so that relative paths will work
$ISO_MKISOFS_BIN -o "$ISO_DIR/$ISO_PREFIX.iso" -b boot/boot.img -c boot/monboot.catalogi -pad \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-R -J -volid "$ISO_VOLID" -v . >&8
	#-R -J -volid "$ISO_VOLID" -v "$BUILD_DIR/isofs"  >&8
	#-R -J -volid "$ISO_VOLID" -v "${ISO_FILES[@]}"  >&8
StopIfError "Could not create ISO image"

ISO_IMAGES=( "${ISO_IMAGES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
popd >&8
Print "Wrote ISO Image $ISO_DIR/$ISO_PREFIX.iso ($(du -h "$ISO_DIR/$ISO_PREFIX.iso"| tr -s " \t" " " | cut -d " " -f 1))"

# Add ISO image to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
