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

Log "Copying kernel"
#cp -pL $v $KERNEL_FILE $TMP_DIR/kernel >&2
cp -pL $v $KERNEL_FILE $TMP_DIR/isofs/isolinux/kernel >&2
cp $v $TMP_DIR/initrd.cgz $TMP_DIR/isofs/isolinux/initrd.cgz >&2

#ISO_FILES=( ${ISO_FILES[@]} $TMP_DIR/kernel $TMP_DIR/initrd.cgz )
# in case the user populates this array manually we must not forget to copy
# these files to our temporary isofs
if test "${#ISO_FILES[@]}" -gt 0 ; then
    cp -pL $v ${ISO_FILES[@]}  $TMP_DIR/isofs/isolinux/ >&2
fi

mkdir -p $v "$ISO_DIR" >&2
StopIfError "Could not create ISO ouput directory ($ISO_DIR)"

