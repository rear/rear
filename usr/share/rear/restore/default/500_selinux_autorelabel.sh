# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# In de /usr/share/rear/conf/default.conf file the variable to temporary disasble SELinux during backup is
# defined as BACKUP_SELINUX_DISABLE=1 (so, by default disable SELinux during backup/archive of our system disks).
# In most case this is honored with BACKUP=NETFS setting using tar or rsync backup programs.

# Skip when disabling SELinux policy during backup/restore with NETFS or RSYNC is not requested:
is_true "$BACKUP_SELINUX_DISABLE" || return 0

# When BACKUP_SELINUX_DISABLE=1 has been defined we force a rebaling of all files after recovery (including reboot).
# Force SELinux relabeling of all files after reboot of the recovered system:
touch $TARGET_FS_ROOT/.autorelabel
LogPrint "Created SELinux $TARGET_FS_ROOT/.autorelabel file : after reboot SELinux will relabel all files"
