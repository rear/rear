# if this system has a hvc console then start a getty on it

if [ -d $ROOTFS_DIR/usr/lib/systemd/system ] && [ -c /dev/hvc0 ] ; then
	pushd $ROOTFS_DIR/usr/lib/systemd/system/getty.target.wants >/dev/null
	ln -s ../getty\@.service getty\@hvc0.service
	popd >/dev/null
	Log "hvc console support enabled"
fi
