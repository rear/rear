# if this system has a XEN console then start a mingetty on it

if [ -c /dev/xvc0 ] ; then
	cat <<-EOF >>$ROOTFS_DIR/etc/inittab
		co:2345:respawn:/bin/mingetty --noclear xvc0
	EOF
	Log "XEN PV console support enabled"
fi
