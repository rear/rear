# make sure that the rootfs contains a usable system

if ! chroot $ROOTFS_DIR bash -c true ; then
	KEEP_BUILD_DIR=1
	BugError "ROOTFS_DIR '$ROOTFS_DIR' is broken, chroot bash test failed."
fi
