# if this system has a hvc console then start a getty on it

if [ -c /dev/hvc0 ] ; then
	pushd $ROOTFS_DIR/usr/lib/systemd/system/getty.target.wants >&8
	ln -s ../getty\@.service getty\@hvc0.service
	popd >&8
	Log "hvc console support enabled"
fi
