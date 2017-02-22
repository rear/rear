#
# backup/ZYPPER/default/500_make_backup.sh
# 500_make_backup.sh is the default script name to make a backup
# see backup/readme
# in this case it is not an usual file-based backup/restore method
# see BACKUP=ZYPPER in conf/default.conf
#

LogPrint "Determining RPM packages data for ZYPPER backup method..."

# Create the directory where the data for BACKUP=ZYPPER gets stored.
# This is below $VAR_DIR because the whole $VAR_DIR gets automatically
# copied into the ReaR recovery system so that this way the data is
# automatically available for "rear recover":
local zypper_backup_dir=$VAR_DIR/backup/$BACKUP
test -d $zypper_backup_dir || mkdir $verbose -p -m 755 $zypper_backup_dir

# Determine all installed RPM packages:
rpm --query --all --last >$zypper_backup_dir/installed_RPMs

# Determine which of the installed RPM packages
# are not required by other installed RPM packages.
# Those independently installed RPM packages are those that
# either are intentionally installed by the admin
# or got unintentionally installed via recommended by other RPMs
# or are no longer required (orphans) after other RPMs had been removed:
cat /dev/null >$zypper_backup_dir/independent_RPMs
local rpm_package=""
for rpm_package in $( cut -d ' ' -f1 $zypper_backup_dir/installed_RPMs ) ; do
    # rpm_package is of the form name-version-release.architecture
    rpm_package_name_version=${rpm_package%-*}
    rpm_package_name=${rpm_package_name_version%-*}
    # The only reliably working way how to find out if an installed RPM package
    # is needed by another installed RPM package is to test if it can be erased.
    # In particular regarding "rpm -q --whatrequires" versus "rpm -e --test" see
    # https://lists.opensuse.org/opensuse-de/2011-11/msg00076.html
    # that reads (excerpt):
    # "rpm -q --whatrequires <something>" does not show all package dependencies because
    # this shows only the dependencies regarding the exact RPM capability <something>.
    # Only "rpm -e --test <package>" shows you all other packages which depend on package.
    if rpm --erase --test $rpm_package &>/dev/null ; then
        echo $rpm_package >>$zypper_backup_dir/independent_RPMs
        # Only print the "interesting" RPMs on the screen:
        LogPrint "$rpm_package_name is independent of other installed RPM packages"
    else
        # Do not print all those zillions of RPMs that are needed by other RPMs:
        Log "$rpm_package_name_version is needed by other installed RPM package(s)"
    fi
done

LogPrint "Wrote RPM packages data for ZYPPER backup method to $zypper_backup_dir"

