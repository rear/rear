# #00_merge_skeletons.sh
#
# merge skeleton directories for Relax & Recover
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

ProgressStart "Creating root FS layout"
pushd $SHARE_DIR/skel >/dev/null
for dir in default "$ARCH" "$OS" "$OS_VENDOR/default" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" "$BACKUP" "$OUTPUT" ; do
	if test -s "$dir".tar.gz ; then
		Log "Adding '$dir.tar.gz'"
		tar -C $ROOTFS_DIR -xvzf "$dir".tar.gz 1>&8
	elif test -d "$dir" ; then
		Log "Adding '$dir'"
		tar -C "$dir" -c . | tar -C $ROOTFS_DIR -xv 1>&8
	else
		Log "No '$dir' or '$dir.tar.gz' found"
	fi
done
popd >/dev/null
ProgressStop
