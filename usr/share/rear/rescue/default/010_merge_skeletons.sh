# 010_merge_skeletons.sh
#
# merge skeleton directories for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LogPrint "Creating root filesystem layout"
pushd $SHARE_DIR/skel >/dev/null
for dir in default "$ARCH" "$OS" \
		"$OS_MASTER_VENDOR/default" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" \
		"$OS_VENDOR/default" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" \
		"$BACKUP" "$OUTPUT" ; do
	if test -z "$dir" ; then
		# silently skip if $dir it empty, e.g. if OS_MASTER_* is empty
		continue
	elif test -s "$dir".tar.gz ; then
		Log "Adding '$dir.tar.gz'"
		tar -C $ROOTFS_DIR -xvzf "$dir".tar.gz >/dev/null
	elif test -d "$dir" ; then
		Log "Adding '$dir'"
		tar -C "$dir" -c . | tar -C $ROOTFS_DIR -xv >/dev/null
	else
		Debug "No '$dir' or '$dir.tar.gz' found"
	fi
done
popd >/dev/null

# make sure the owner is root if running from checkout
chown -R root:root $ROOTFS_DIR
