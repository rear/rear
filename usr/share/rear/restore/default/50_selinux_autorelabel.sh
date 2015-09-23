# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# when the variable BACKUP_SELINUX_DISABLE is unset then silently return
[[ ! "$BACKUP_SELINUX_DISABLE"  =~ ^[yY1] ]] && return

# force relabeling after reboot of the recovered system
touch /mnt/local/.autorelabel
Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
