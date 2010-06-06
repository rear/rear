#
# debian has to do everything different from all other Linux systems ...

if test -x "$(type -p lilo.real)" ; then
	cp -af "$(type -p lilo.real)" $ROOTFS_DIR/bin/lilo
	cp -a /lib/libdevmapper* $ROOTFS_DIR/lib/
fi

if test -x "$(type -p lvmiopversion)" ; then
	cp -af /lib/lvm-* $ROOTFS_DIR/lib/
	cp -af /sbin/lvm* $ROOTFS_DIR/bin/
fi
