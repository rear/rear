#
# debian has to do everything different from all other Linux systems ...

if test -x "$(type -p lilo.real)" ; then
	cp -af $v "$(type -p lilo.real)" $ROOTFS_DIR/bin/lilo
	cp -a $v /lib/libdevmapper* $ROOTFS_DIR/lib/
fi

if test -x "$(type -p lvmiopversion)" ; then
	cp -af $v /lib/lvm-* $ROOTFS_DIR/lib/
	cp -af $v /sbin/lvm* $ROOTFS_DIR/bin/
fi
