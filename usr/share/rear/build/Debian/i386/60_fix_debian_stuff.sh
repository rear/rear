#
# debian has to do everything different from all other Linux systems ...

test -x "$(which lilo.real)" && {
	cp -af "$(which lilo.real)" $ROOTFS_DIR/bin/lilo
	cp -a /lib/libdevmapper* $ROOTFS_DIR/lib/
}

test -x "$(which lvmiopversion)" && {
	cp -af /lib/lvm-* $ROOTFS_DIR/lib/
	cp -af /sbin/lvm* $ROOTFS_DIR/bin/
}
