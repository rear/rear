#
# debian has to do everything different from all other Linux systems ...

test -x "$(type -p lilo.real)" && {
	cp -af "$(type -p lilo.real)" $ROOTFS_DIR/bin/lilo
	cp -a /lib/libdevmapper* $ROOTFS_DIR/lib/
}

test -x "$(type -p lvmiopversion)" && {
	cp -af /lib/lvm-* $ROOTFS_DIR/lib/
	cp -af /sbin/lvm* $ROOTFS_DIR/bin/
}
