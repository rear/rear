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
cat $( dirname "$backuparchive" )/selinux_contexts.dat | chroot $TARGET_FS_ROOT/ xargs -n 2 chcon -h $v

# SELinux policy can become invalid if installed too early in the restore process, so reinstall it to ensure
# that it is valid after we've restored the SELinux contexts
if rpm_package=$(rpm $v --root $TARGET_FS_ROOT --query selinux-policy-targeted) ; then
	rpm_package_name_version=${rpm_package%-*}
	rpm_package_name=${rpm_package_name_version%-*}
        LogPrint "Reinstalling $rpm_package_name"
	# Sometimes the version of the package isn't available to reinstall, so if reinstall
	# fails, do a regular package upgrade
        yum $verbose --installroot=$TARGET_FS_ROOT -y reinstall "$rpm_package_name" 1>&2 || \
        yum $verbose --installroot=$TARGET_FS_ROOT -y upgrade "$rpm_package_name" 1>&2
fi
