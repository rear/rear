# Start SELinux if it was stopped - check presence of  $TMP_DIR/selinux.mode

[ -f $TMP_DIR/selinux.mode ] && {
	cat $TMP_DIR/selinux.mode > $SELINUX_ENFORCE
	Log "Restored original SELinux mode"
}
