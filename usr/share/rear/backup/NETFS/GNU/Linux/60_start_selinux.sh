# Start SELinux if it was stopped - check presence of /tmp/selinux.mode
[ -f $TMP_DIR/selinux.mode ] && {
	cat $TMP_DIR/selinux.mode > /selinux/enforce
	Log "Restored original SELinux mode"
	touch "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/selinux.autorelabel"
	Log "Trigger autorelabel (SELinux) file"
	}
