#
# backup/YUM/default/500_make_backup.sh
# 500_make_backup.sh is the default script name to make a backup
# see backup/readme
#

# For BACKUP=YUM the RPM data got stored into the
# ReaR recovery system via prep/YUM/default/400_prep_rpm.sh
# When backup/YUM/default/500_make_backup.sh runs
# the ReaR recovery system is already made
# (its recovery/rescue system initramfs/initrd is already created)
# so that at this state nothing can be stored into the recovery system.
# At this state an additional normal file based backup can be made
# in particular to backup all those files that do not belong to an installed YUM package
# (e.g. files in /home/ directories or third-party software in /opt/) or files
# that belong to a YUM package but are changed (i.e. where "rpm -V" reports differences)
# (e.g. config files like /etc/default/grub).

if ! is_true "$YUM_BACKUP_FILES" ; then
	LogPrint "Not backing up system files (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
	return
fi
LogPrint "Backing up system files (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Store the files generated here in the same directory as the backup archive file
# so they are available during recovery
local yum_backup_dir=$(dirname "$backuparchive")
test -d $yum_backup_dir || mkdir $verbose -p -m 755 $yum_backup_dir

# Catalog all files provided by RPM packages
LogPrint "Cataloging all unmodified files provided by RPM packages"
for file in $(rpm -Vva | grep '^\.\.\.\.\.\.\.\.\.' | grep -v '^...........c' | cut -c 14-); do [ -f $file ] && echo $file; done | sort | uniq > $yum_backup_dir/rpm_provided_files.dat

# Gather RPM verification data
rpm -Va > $yum_backup_dir/rpm_verification.dat || true		# don't fail - we're just capturing RPM file verfication

# Use the RPM verification data to catalog RPM-provided files which have been modified...
grep -v ^missing $yum_backup_dir/rpm_verification.dat | cut -c 14- > $yum_backup_dir/rpm_modified_files.dat
# ...or are missing
grep ^missing $yum_backup_dir/rpm_verification.dat | cut -c 14- > $yum_backup_dir/rpm_missing_files.dat || true		# don't fail if no files are missing

# Create an exclusion file which is a list of the RPM-provided files which have NOT been modified
grep -Fvxf $yum_backup_dir/rpm_modified_files.dat $yum_backup_dir/rpm_provided_files.dat > $yum_backup_dir/rpm_backup_exclude_files.dat

# Locate all files which share an inode with the files listed in rpm_backup_exclude_files.dat.tmp
if is_true "$YUM_BACKUP_FILES_FULL_EXCL" ; then
(
	LogPrint "Building comprehensive exclusion list by locating all files which share inodes with the files in the exclusion list."
	LogPrint "This may take some time..."
	count=0; cmd2=""
	let "maxArgLen=$(getconf ARG_MAX) / 100" # Limit how long our find command line will be for each invocation
	mv $yum_backup_dir/rpm_backup_exclude_files.dat $yum_backup_dir/rpm_backup_exclude_files.dat.tmp
	cat $yum_backup_dir/rpm_backup_exclude_files.dat.tmp | while read fname
	do
        	[ $count -gt 0 ] && {
                	cmd2=$(echo -n "$cmd2 -o -samefile $fname")
        	} || {
                	cmd2=$(echo -n "$cmd2 -samefile $fname")
        	}
            # Aviod ShellCheck
            # SC2000: See if you can use ${#variable} instead
            # https://github.com/koalaman/shellcheck/wiki/SC2000
            # The code before was
            # curCmdLen=$(echo "$cmd2" | wc -c)
            # so curCmdLen is ${#cmd2} + 1 because of the newline of 'echo'
            # but I <jsmeix@suse.de> don't know for sure if + 1 is needed or not so I keep it:
        	curCmdLen=$(( ${#cmd2} + 1 ))
        	[ $curCmdLen -gt $maxArgLen ] && {
			# Simple "something is still going on" indicator by printing dots
			# directly to stdout which is fd7 (see lib/_input-output-functions.sh)
			# and not using a Print function to always print to the original stdout
			# i.e. to the terminal wherefrom the user has started "rear recover":
			echo -n "." >&7
                	find -L / -xdev $cmd2
                	count=0
                	cmd2=""
        	} || {
                	let ++count 	# Must pre-increment here. If post-increment, let's exit code is 1 when count==0
        	}
	done > $yum_backup_dir/rpm_backup_exclude_files.dat
	rm -f $yum_backup_dir/rpm_backup_exclude_files.dat.tmp
	# One newline ends the "something is still going on" indicator:
	echo "" >&7
)
fi

LogPrint "Creating $BACKUP_PROG archive '$backuparchive'"
# Add the --selinux option to be safe with SELinux context restoration (from restore/NETFS/default/400_restore_backup.sh)
if ! is_true "$BACKUP_SELINUX_DISABLE" ; then
    if tar --usage | grep -q selinux ; then
        BACKUP_PROG_OPTIONS+=( --selinux )
    fi
    if tar --usage | grep -wq -- --xattrs ; then
        BACKUP_PROG_OPTIONS+=( --xattrs )
    fi
    if tar --usage | grep -wq -- --xattrs-include ; then
        BACKUP_PROG_OPTIONS+=( '--xattrs-include="*.*"' )
    fi
fi

# Generate the actual backup archive, excluding all of the RPM-provided files which have NOT been modified
Log tar --preserve-permissions --same-owner --warning=no-xdev --sparse --block-number --totals --no-wildcards-match-slash --one-file-system --ignore-failed-read ${BACKUP_PROG_OPTIONS[@]} --gzip -C / -c -f $backuparchive --exclude-from=$yum_backup_dir/rpm_backup_exclude_files.dat -X $TMP_DIR/backup-exclude.txt $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE
tar --preserve-permissions --same-owner --warning=no-xdev --sparse --block-number --totals --no-wildcards-match-slash --one-file-system --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}" --gzip -C / -c -f $backuparchive --exclude-from=$yum_backup_dir/rpm_backup_exclude_files.dat -X $TMP_DIR/backup-exclude.txt $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
