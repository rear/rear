# #00_merge_skeletons.sh
#
# merge skeleton directories for Relax-and-Recover
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

LogPrint "Creating root filesystem layout"
pushd $SHARE_DIR/skel >&8
for dir in default "$ARCH" "$OS" \
		"$OS_MASTER_VENDOR/default" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" \
		"$OS_VENDOR/default" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" \
		"$BACKUP" "$OUTPUT" ; do
	if test -z "$dir" ; then
		# silently skip if $dir it empty, e.g. if OS_MASTER_* is empty
		continue
	elif test -s "$dir".tar.gz ; then
		Log "Adding '$dir.tar.gz'"
		tar -C $ROOTFS_DIR -xvzf "$dir".tar.gz >&8
	elif test -d "$dir" ; then
		Log "Adding '$dir'"
		tar -C "$dir" -c . | tar -C $ROOTFS_DIR -xv >&8
	else
		Debug "No '$dir' or '$dir.tar.gz' found"
	fi
done
popd >&8

# make sure the owner is root if running from checkout
chown -R root:root $ROOTFS_DIR
