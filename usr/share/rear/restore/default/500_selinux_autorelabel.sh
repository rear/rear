# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Skip when disabling SELinux policy during backup/restore with NETFS or RSYNC is not wanted:
is_true "$BACKUP_SELINUX_DISABLE" || return 0

# Force SELinux relabeling of all files after reboot of the recovered system:
touch $TARGET_FS_ROOT/.autorelabel
LogPrint "Created SELinux $TARGET_FS_ROOT/.autorelabel file : after reboot SELinux will relabel all files"
