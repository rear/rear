# Stop SELinux if BACKUP_SELINUX_DISABLE is set

# Only stop SELinux if both conditions are met:
# - BACKUP_SELINUX_DISABLE is true
# - SELinux is actually in use on the system
is_true "$BACKUP_SELINUX_DISABLE" || return 0
is_true "$SELINUX_IN_USE" || return 0

# Set SELinux to permissive mode (0) during backup
echo "0" > $SELINUX_ENFORCE
Log "Temporarily stopping SELinux enforce mode with BACKUP=${BACKUP} and BACKUP_PROG=${BACKUP_PROG} backup"

