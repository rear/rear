#
# debian has to do everything different from all other Linux systems ...

if test -x "$(get_path lilo.real)" ; then
	cp -af $v "$(get_path lilo.real)" $ROOTFS_DIR/bin/lilo >&2
	cp -a $v /lib/libdevmapper* $ROOTFS_DIR/lib/ >&2
fi

if test -x "$(get_path lvmiopversion)" ; then
	cp -af $v /lib/lvm-* $ROOTFS_DIR/lib/ >&2
	cp -af $v /sbin/lvm* $ROOTFS_DIR/bin/ >&2
fi
