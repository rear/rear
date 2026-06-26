# Restore original SELinux enforce mode if it was stopped during backup

# Only restore if both conditions are met:
# - BACKUP_SELINUX_DISABLE is true (meaning we stopped SELinux during backup)
# - SELinux is actually in use on the system
is_true "$BACKUP_SELINUX_DISABLE" || return 0
is_true "$SELINUX_IN_USE" || return 0

# Restore original SELinux enforcing mode
echo "$SELINUX_ENFORCING" > $SELINUX_ENFORCE
Log "Restored original SELinux mode"
