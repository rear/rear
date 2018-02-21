#
# restore/YUM/default/600_restore_selinux_contexts.sh
#

# For BACKUP=YUM the SELinux security context data for all files can be stored for
# the ReaR recovery system via backup/YUM/default/600_capture_selinux_contexts.sh
# to ensure that the contexts are precisely replicated.
# Only available if YUM_BACKUP_FILES is set to create a file archive.

if ! is_true "$YUM_BACKUP_FILES" ; then
        LogPrint "Not restoring SELinux contexts (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
        return
fi
if ! is_true "$YUM_BACKUP_SELINUX_CONTEXTS" ; then
        LogPrint "Not restoring SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"
        return
fi
LogPrint "Restoring SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

cat $( dirname "$backuparchive" )/selinux_contexts.dat | chroot $TARGET_FS_ROOT/ xargs -n 2 chcon -h $v

# SELinux policy can become invalid if installed too early in the restore process, so reinstall it to ensure
# that it is valid after we've restored the SELinux contexts
if rpm_package=$(rpm $v --root $TARGET_FS_ROOT --query selinux-policy-targeted) ; then
	rpm_package_name_version="${rpm_package%-*}"
	rpm_package_name="${rpm_package_name_version%-*}"
        LogPrint "Reinstalling $rpm_package_name"
	# Sometimes the version of the package isn't available to reinstall, so if reinstall
	# fails, do a regular package upgrade
        yum $verbose --installroot=$TARGET_FS_ROOT -y reinstall "$rpm_package_name" 1>&2 || \
        yum $verbose --installroot=$TARGET_FS_ROOT -y upgrade "$rpm_package_name" 1>&2
fi

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
