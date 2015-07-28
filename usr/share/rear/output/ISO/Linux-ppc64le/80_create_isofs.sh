# #80_create_isofs.sh
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

Log "Copying kernel"
cp -pL $v $KERNEL_FILE $TMP_DIR/kernel >&2

ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/kernel initrd.cgz )
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

pushd $TMP_DIR >&8 # so that relative paths will work
$ISO_MKISOFS_BIN $v -o "$ISO_DIR/$ISO_PREFIX.iso" -U -chrp-boot \
	-R -J -volid "$ISO_VOLID" -v -graft-points "${ISO_FILES[@]}" >&8
StopIfError "Could not create ISO image"
ISO_IMAGES=( "${ISO_IMAGES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
popd >&8
Print "Wrote ISO Image $ISO_DIR/$ISO_PREFIX.iso ($(du -h "$ISO_DIR/$ISO_PREFIX.iso"| tr -s " \t" " " | cut -d " " -f 1))"

# Add ISO image to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_DIR/$ISO_PREFIX.iso" )
