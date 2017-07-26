#
# restore/YUM/default/600_restore_selinux_contexts.sh
#

# For BACKUP=YUM the RPM data got stored into the
# ReaR recovery system via prep/YUM/default/400_prep_rpm.sh
# When backup/YUM/default/500_make_backup.sh runs
# the ReaR recovery system is already made
# (its recovery/rescue system initramfs/initrd is already created)
# so that at this state nothing can be stored into the recovery system.
# At this state an additional normal file based backup can be made
# in particular to backup all those files that do not belong to an installed RPM package
# (e.g. files in /home/ directories or third-party software in /opt/) or files
# that belong to a RPM package but are changed (i.e. where "rpm -V" reports differences)
# (e.g. config files like /etc/default/grub).

if ! is_true "$YUM_BACKUP_FILES" ; then
        LogPrint "Not restoring SELinux contexts (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
        return
fi

if ! is_true "$YUM_BACKUP_SELINUX_CONTEXTS" ; then
        LogPrint "Not restoring SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"
        return
fi
LogPrint "Restoring SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"

cat $( dirname "$backuparchive" )/selinux_contexts.dat | chroot $TARGET_FS_ROOT/ xargs -n 2 chcon -h -v
