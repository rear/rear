#
# backup/ZYPPER/default/500_make_backup.sh
# 500_make_backup.sh is the default script name to make a backup
# see backup/readme
#

# For BACKUP=ZYPPER the zypper data and RPM data got stored into the
# ReaR recovery system via prep/ZYPPER/default/400_prep_zypper.sh
# When backup/ZYPPER/default/500_make_backup.sh runs
# the ReaR recovery system is already made
# (its recovery/rescue system initramfs/initrd is already created)
# so that at this state nothing can be stored into the recovery system.
# At this state an additional normal file based backup can be made
# in particular to backup all those files that do not belong to an installed RPM package
# (e.g. files in /home/ directories or third-party software in /opt/) or files
# that belong to a RPM package but are changed (i.e. where "rpm -V" reports differences)
# (e.g. config files like /etc/default/grub).

# Currently there is nothing implemented:
return 0

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

