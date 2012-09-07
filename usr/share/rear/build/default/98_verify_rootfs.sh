# make sure that the rootfs contains a usable system

# In case the filesystem is mounted 'noexec' we skip a chroot bash test
tmp_filesystem=$(filesystem_name $ROOTFS_DIR)

if grep -qE '^\S+ '$tmp_filesystem' \S+ \S*\bnoexec\b\S* ' /proc/mounts; then
	LogPrint "WARNING: Filesystem $tmp_filesystem is mounted 'noexec', aborting chroot bash test"
	Log "The above error means that we cannot test our chrooted environment because
we need the 'exec' option set to the filesystem. One way to achieve this is
by doing: mount -o remount,exec $tmp_filesystem"
	return
fi

# The chroot bash test ensures that we have a working bash on our rescue image
if ! chroot $ROOTFS_DIR bash -c true ; then
	KEEP_BUILD_DIR=1
	BugError "ROOTFS_DIR '$ROOTFS_DIR' is broken, chroot bash test failed."
fi
