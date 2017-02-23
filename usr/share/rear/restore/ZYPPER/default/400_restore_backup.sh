#
# restore/ZYPPER/default/400_restore_backup.sh
# 400_restore_backup.sh is the default script name to exec the restore itself
# see restore/readme
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# For BACKUP=ZYPPER the zypper data and RPM data got stored into the
# ReaR recovery system via prep/ZYPPER/default/400_prep_zypper.sh
# in files in the $VAR_DIR/ZYPPER directory.
local zypper_backup_dir=$VAR_DIR/backup/$BACKUP

# Add zypper repositories:
test "${ZYPPER_REPOSITORIES[@]:-}" || Error "No zypper repository (empty ZYPPER_REPOSITORIES array)"
local zypper_repository=""
local zypper_repository_number=0
for zypper_repository in "${ZYPPER_REPOSITORIES[@]:-}" ; do
    zypper_repository_number=$(( zypper_repository_number + 1 ))
    zypper $verbose --non-interactive --root $TARGET_FS_ROOT addrepo --no-gpg-checks $zypper_repository repository$zypper_repository_number
done
# To be on the safe side explicitly refresh the new added zypper repositories:
zypper $verbose --non-interactive --root $TARGET_FS_ROOT refresh

# First and foremost install the very basic stuff:
LogPrint "Installing the very basic stuff (aaa_base and what it requires):"
zypper $verbose --non-interactive --root $TARGET_FS_ROOT install aaa_base
# aaa_base requires filesystem so that zypper installs filesystem before aaa_base
# but for a clean filesystem installation RPM needs users and gropus
# as shown by RPM as warnings like (excerpt):
#   warning: user news does not exist - using root
#   warning: group news does not exist - using root
#   warning: group dialout does not exist - using root
#   warning: user uucp does not exist - using root
# Because those users and gropus are created by aaa_base scriptlets and
# also RPM installation of permissions pam libutempter0 shadow util-linux
# (that get also installed before aaa_base by zypper installation of aaa_base)
# needs users and gropus that are created by aaa_base scriptlets so that
# those packages are enforced installed a second time after aaa_base was installed.
# To be safe against changes in the list of packages that need to be
# enforced installed a second time after aaa_base was installed
# simply all packages that are installed up to now are
# enforced installed a second time:
local rpms_in_installion_order=""
rpms_in_installion_order=$( rpm $v --root $TARGET_FS_ROOT --query --all --last | cut -d ' ' -f 1 | tac )
local rpm_package=""
local rpm_package_name_version=""
local rpm_package_name=""
for rpm_package in "$rpms_in_installion_order" ; do
    # rpm_package is of the form name-version-release.architecture
    rpm_package_name_version=${rpm_package%-*}
    rpm_package_name=${rpm_package_name_version%-*}
    zypper $verbose --non-interactive --root $TARGET_FS_ROOT install --force $rpm_package_name
done
# Report the differences of what is in the RPM packages
# compared to the actually installed files in the target system.
# Differences are only reported here so that the user is informed
# but differences are not necessarily an error.
LogPrint "Differences of what is in the basic RPM packages compared to what is actually installed:"
# Report all differences except when only the mtime differs but the file content (MD5 sum) is still the same:
if rpm $v --root $TARGET_FS_ROOT --verify --all --nomtime ; then
    LogPrint "No differences between basic RPM packages and what is actually installed."
else
    LogPrint "Differences between basic RPM packages and what is installed are not necessarily an error."
fi

# The actual software installation:
for rpm_package in $( cut -d ' ' -f1 $zypper_backup_dir/independent_RPMs ) ; do
    # rpm_package is of the form name-version-release.architecture
    rpm_package_name_version=${rpm_package%-*}
    rpm_package_name=${rpm_package_name_version%-*}
    zypper $verbose --non-interactive --root $TARGET_FS_ROOT install $rpm_package_name
done
# Report the differences of what is in the RPM packages
# compared to the actually installed files in the target system.
# Differences are only reported here so that the user is informed
# but differences are not necessarily an error.
LogPrint "Differences of what is in all RPM packages compared to what is actually installed:"
# Report all differences except when only the mtime differs but the file content (MD5 sum) is still the same:
if rpm $v --root $TARGET_FS_ROOT --verify --all --nomtime ; then
    LogPrint "No differences between RPM packages and what is actually installed."
else
    LogPrint "Differences between RPM packages and what is installed are not necessarily an error."
fi

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

