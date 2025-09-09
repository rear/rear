#
# restore/YUM/default/400_restore_packages.sh
# 400_restore_packages.sh is the default script name to exec the restore itself
# see restore/readme
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# For BACKUP=YUM the RPM data got stored into the
# ReaR recovery system via prep/YUM/default/400_prep_rpm.sh
# in files in the $VAR_DIR/YUM directory.
local yum_backup_dir=$( dirname "$backuparchive" )

# Add rpm repositories:
LogPrint "Adding rpm repositories from $yum_backup_dir"
local repoList=""
for repo in $(cat $yum_backup_dir/rpm_repositories.dat)
do
	repoList+=" --enablerepo=$repo"
done
mkdir -p $TARGET_FS_ROOT/etc/yum.repos.d
cp -a /etc/yum.repos.d/* $TARGET_FS_ROOT/etc/yum.repos.d/

LogPrint "Running yum makecache"
yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) -y --installroot=$TARGET_FS_ROOT makecache 1>&2

# Provide all /etc/products.d/ stuff in the target system:
#cp $verbose --archive /etc/products.d $TARGET_FS_ROOT/etc

# First and foremost install the very basic stuff:
local rpm_package_name="basesystem"
LogPrint "Installing the very basic stuff ('$rpm_package_name' and what it requires)"
yum $verbose --disablerepo=* $repoList --installroot=$TARGET_FS_ROOT --releasever=$(cat $yum_backup_dir/releasever.dat) -y install "$rpm_package_name" 1>&2
# aaa_base requires filesystem so that yum installs filesystem before aaa_base
# but for a clean filesystem installation YUM needs users and groups
# as shown by RPM as warnings like (excerpt):
#   warning: user news does not exist - using root
#   warning: group news does not exist - using root
#   warning: group dialout does not exist - using root
#   warning: user uucp does not exist - using root
# Because those users and groups are created by aaa_base scriptlets and
# also RPM installation of permissions pam libutempter0 shadow util-linux
# (that get also installed before aaa_base by yum installation of aaa_base)
# needs users and groups that are created by aaa_base scriptlets so that
# those packages are enforced installed a second time after aaa_base was installed.
# To be safe against changes in the list of packages that need to be
# enforced installed a second time after aaa_base was installed
# simply all packages that are installed up to now are
# enforced installed a second time:
local rpms_in_installion_order=""
rpms_in_installion_order="$( rpm $v --root $TARGET_FS_ROOT --query --all --last | cut -d ' ' -f 1 | tac )"
local rpm_package=""
local rpm_package_name_version=""
for rpm_package in $rpms_in_installion_order ; do
    # Simple "something is still going on" indicator by printing dots
    # directly to stdout which is fd7 (see lib/_framework-setup-and-functions.sh)
    # and not using a Print function to always print to the original stdout
    # i.e. to the terminal wherefrom the user has started "rear recover":
    echo -n "." >&7
    # rpm_package is of the form name-version-release.architecture
    rpm_package_name_version="${rpm_package%-*}"
    rpm_package_name="${rpm_package_name_version%-*}"
    test "gpg-pubkey" = "$rpm_package_name" && rpm_package_name=$rpm_package
    yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) --installroot=$TARGET_FS_ROOT -y reinstall "$rpm_package_name" 1>&2 || echo -n \! >&7 # print a '!' to ignore errors so 'rear recover' doesn't fail on individual pkg failures
done
# One newline ends the "something is still going on" indicator:
echo "" >&7
# Check the differences of what is in the RPM packages
# compared to the actually installed files in the target system.
# Differences are only reported here so that the user is informed
# but differences are not necessarily an error.
Log "Checking differences of what is in the basic RPM packages compared to what is actually installed"
# Report all differences except when only the mtime differs but the file content (MD5 sum) is still the same.
# Do not run "rpm -v" because that lists the results for all files in the RPM package also when nothing differs:
if rpm --root $TARGET_FS_ROOT --verify --all --nomtime 1>&2 ; then
    Log "No differences between basic RPM packages and what is actually installed"
else
    LogPrint "There are differences between what is in the basic RPM packages and what is actually installed (this is not necessarily an error), check the log file"
fi

# The actual software installation:
if test "independent_RPMs" = "$YUM_INSTALL_RPMS" ; then
    LogPrint "Installing independent RPM packages and what they require and recommend (needs time - be patient)"
    # Installation must happen in reverse ordering of what is listed in yum_backup_dir/independent_RPMs
    # because therein the latest installed RPMs are listed topmost:
    for rpm_package in $( tac $yum_backup_dir/independent_RPMs ) ; do
        # Simple "something is still going on" indicator by printing dots
        # directly to stdout which is fd7 (see lib/_framework-setup-and-functions.sh)
        # and not using a Print function to always print to the original stdout
        # i.e. to the terminal wherefrom the user has started "rear recover":
        echo -n "." >&7
        # rpm_package is of the form name-version-release.architecture
        rpm_package_name_version="${rpm_package%-*}"
        rpm_package_name="${rpm_package_name_version%-*}"
        # Dirty hack for "gpg-pubkey" packages where several of them with different version and release
        # can be (and actually are) installed at the same time e.g. on my <jsmeix@suse.de> SLES12 system
        # where "rpm -qa | grep gpg-pubkey" results things like gpg-pubkey-1a2b-3c4d and gpg-pubkey-5e6f-7890
        # so that the exact "gpg-pubkey" package with version and release must be specified to be installed:
        test "gpg-pubkey" = "$rpm_package_name" && rpm_package_name=$rpm_package
        # Report when a non-basic package cannot be installed but do not treat that as an error that aborts "rear recover":
  	if yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) --installroot=$TARGET_FS_ROOT -y install "$rpm_package_name_version" 1>&2 ; then
            Log "Installed '$rpm_package_name_version'"
        else
            Log "Failed to install '$rpm_package_name_version', falling back to '$rpm_package_name'"
	    if yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) --installroot=$TARGET_FS_ROOT -y install "$rpm_package_name" 1>&2 ; then
                Log "Installed '$rpm_package_name'"
	    else
            	echo "!" >&7
            	# Report also the version because e.g. for gpg-pubkey
            	LogPrint "Failed to install '$rpm_package_name', check the log file"
            fi
        fi
    done
else
    LogPrint "Installing all other RPM packages and what they require (needs time)"
    # Installation must happen in reverse ordering of what is listed in yum_backup_dir/installed_RPMs
    # because therein the latest installed RPMs are listed topmost:
    for rpm_package in $( tac $yum_backup_dir/installed_RPMs | cut -d ' ' -f1 ) ; do
        # Simple "something is still going on" indicator by printing dots
        # directly to stdout which is fd7 (see lib/_framework-setup-and-functions.sh)
        # and not using a Print function to always print to the original stdout
        # i.e. to the terminal wherefrom the user has started "rear recover":
        echo -n "." >&7
        # rpm_package is of the form name-version-release.architecture
        rpm_package_name_version="${rpm_package%-*}"
        rpm_package_name="${rpm_package_name_version%-*}"
	if IsInArray "$rpm_package" "${YUM_EXCLUDE_PKGS[@]}" -o IsInArray "$rpm_package_name_version" "${YUM_EXCLUDE_PKGS[@]}" -o IsInArray "$rpm_package_name" "${YUM_EXCLUDE_PKGS[@]}" ; then
            	Log "Skipping '$rpm_package'"
		continue
	fi
        # Dirty hack for "gpg-pubkey" packages where several of them with different version and release
        # can be (and actually are) installed at the same time e.g. on my <jsmeix@suse.de> SLES12 system
        # where "rpm -qa | grep gpg-pubkey" results things like gpg-pubkey-1a2b-3c4d and gpg-pubkey-5e6f-7890
        # so that the exact "gpg-pubkey" package with version and release must be specified to be installed:
        test "gpg-pubkey" = "$rpm_package_name" && rpm_package_name=$rpm_package
        # Report when a non-basic package cannot be installed but do not treat that as an error that aborts "rear recover":
  	if yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) --installroot=$TARGET_FS_ROOT -y install "$rpm_package_name_version" 1>&2 ; then
            Log "Installed '$rpm_package_name_version'"
        else
            Log "Failed to install '$rpm_package_name_version', falling back to '$rpm_package_name'"
	    if yum $verbose --disablerepo=* $repoList --releasever=$(cat $yum_backup_dir/releasever.dat) --installroot=$TARGET_FS_ROOT -y install "$rpm_package_name" 1>&2 ; then
                Log "Installed '$rpm_package_name'"
	    else
                echo -n "!" >&7
                # Report also the version because e.g. for gpg-pubkey
                LogPrint "Failed to install '$rpm_package_name', check the log file"
            fi
        fi
    done
fi
# One newline ends the "something is still going on" indicator:
echo "" >&7

# Check the differences of what is in the RPM packages
# compared to the actually installed files in the target system.
# Differences are only reported here so that the user is informed
# but differences are not necessarily an error.
LogPrint "Checking differences of what is in the RPM packages compared to what is actually installed"
# Report all differences except when only the mtime differs but the file content (MD5 sum) is still the same.
# Do not run "rpm -v" because that lists the results for all files in the RPM package also when nothing differs:
if rpm --root $TARGET_FS_ROOT --verify --all --nomtime 1>&2 ; then
    LogPrint "No differences between RPM packages and what is actually installed"
else
    LogPrint "There are differences between what is in the RPM packages and what is actually installed (this is not necessarily an error), check the log file"
fi

# Any files which were RPM-provided but were missing on the source system should be removed
for missing_file in $( cat $yum_backup_dir/rpm_missing_files.dat )
do
	LogPrint "Removing $missing_file from restored system (it was missing on the source system)"
	rm -rf $TARGET_FS_ROOT/$missing_file || true 	# ignore errors so 'rear recover' doesn't fail on individual file removal failures
done

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

