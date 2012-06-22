# #10_create_initramfs.sh
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

LogPrint "Creating initramfs"

pushd "$ROOTFS_DIR" >&8
find . ! -name "*~"  |\
	tee /dev/fd/8  |\
	cpio -H newc --create --quiet  |\
	gzip > "$TMP_DIR/initrd.cgz"
StopIfError "Could not create initramfs archive"
popd >&8
