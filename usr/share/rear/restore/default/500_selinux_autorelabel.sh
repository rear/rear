# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# In the /usr/share/rear/conf/default.conf file the variable to temporary disasble SELinux during backup is
# defined as BACKUP_SELINUX_DISABLE=1 (so, by default disable SELinux during backup/archive of our system disks).
# In most case this is honored with BACKUP=NETFS setting using tar or rsync backup programs.

# Skip when disabling SELinux policy during backup/restore with NETFS or RSYNC is not requested:
is_true "$BACKUP_SELINUX_DISABLE" || return 0

# When BACKUP_SELINUX_DISABLE=1 has been defined we force a rebaling of all files after recovery (including reboot).
# Force SELinux relabeling of all files after reboot of the recovered system:
touch $TARGET_FS_ROOT/.autorelabel
LogPrint "Created SELinux $TARGET_FS_ROOT/.autorelabel file : after reboot SELinux will relabel all files"

# If we are in enforcing, we should try to relabel before the reboot, because if some files
# are not correctly labelled, system may not be able to start the autorelabel service (ie: /etc/localtime)

test $( grep "SELINUX=enforcing" $TARGET_FS_ROOT/etc/selinux/config ) || return 0

local policy=$( grep "^SELINUXTYPE" $TARGET_FS_ROOT/etc/selinux/config | sed 's/SELINUXTYPE=//' )

Logprint "We try to restore the selinux labels before the first reboot because the configuration is enforcing and autorelabel may fail. \n
        This can take a several minutes."

if [[ -d "$TARGET_FS_ROOT/etc/selinux/${policy}/" ]] ; then
     # setfiles -c $TARGET_FS_ROOT/etc/selinux/${policy}/policy/policy.*  $TARGET_FS_ROOT/etc/selinux/${policy}/contexts/files/file_contexts
     setfiles -r $TARGET_FS_ROOT $TARGET_FS_ROOT/etc/selinux/${policy}/contexts/files/file_contexts $TARGET_FS_ROOT
else
     LogPrint "The configured selinux policy $policy is not accessbible in default path $TARGET_FS_ROOT/etc/selinux/${policy}/. \n
     If the first boot fails, please add 'enforcing=0' on kernel command line, and an autorelabel should fix the labels."
fi

