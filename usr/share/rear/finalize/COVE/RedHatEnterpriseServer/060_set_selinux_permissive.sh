#
# Set SELINUX to permissive mode
#

[ "${OS_VERSION%%.*}" = "10" ] || return 0

selinux_config="$TARGET_FS_ROOT/etc/selinux/config"

[ -f "$selinux_config" ] || return 0

grep -q "^SELINUX=enforcing" "$selinux_config" || return 0

sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' "$selinux_config"

text="During the recovery process of RHEL 10-based systems, SELinux is set to permissive mode to \
successfully relabel the entire file system. After verifying that your system is functioning \
correctly, set SELINUX=enforcing in /etc/selinux/config to return SELinux to enforcing mode."

cove_print_in_frame "WARNING" "$text" || return 0
