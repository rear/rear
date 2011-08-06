# If selinux was turned off for the backup we have to label the
[ -f "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/selinux.autorelabel" ] && { \
	touch /mnt/local/.autorelabel
	Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
	}
