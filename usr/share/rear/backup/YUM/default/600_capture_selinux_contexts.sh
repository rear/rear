#
# backup/YUM/default/600_capture_selinux_contexts.sh
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

# Since SELinux security contexts could be set differently on the source system than
# what the RPM-provided or non-RPM-provided files will have, we need to capture the
# security contexts for every file on the filesystem that will be in the backup archive

if ! is_true "$YUM_BACKUP_FILES" ; then
        LogPrint "Not backing up SELinux contexts (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
        return
fi

if ! is_true "$YUM_BACKUP_SELINUX_CONTEXTS" ; then
        LogPrint "Not backing up SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"
        return
fi
LogPrint "Backing up SELinux contexts (YUM_BACKUP_SELINUX_CONTEXTS=$YUM_BACKUP_SELINUX_CONTEXTS)"

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

local yum_backup_dir=$( dirname "$backuparchive" )
test -d $yum_backup_dir || mkdir $verbose -p -m 755 $yum_backup_dir

find $(cat $TMP_DIR/backup-include.txt) -xdev -exec stat -c "%C %n" {} \; | egrep -w -v -f $TMP_DIR/backup-exclude.txt > $yum_backup_dir/selinux_contexts.dat

# Go back from "set -e -u -o pipefail" to the defaults:
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
