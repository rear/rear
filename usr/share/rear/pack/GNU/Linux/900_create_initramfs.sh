# 100_create_initramfs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LogPrint "Creating initramfs"

pushd "$ROOTFS_DIR" >&8
find . ! -name "*~"  |\
	tee /dev/fd/8  |\
	cpio -H newc --create --quiet  |\
	gzip > "$TMP_DIR/initrd.cgz"
StopIfError "Could not create initramfs archive"
popd >&8
