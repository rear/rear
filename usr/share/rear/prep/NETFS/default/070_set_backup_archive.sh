### Determine the name of the backup archive
### This needs to be after we special case USB devices.

# FIXME: backuparchive is no local variable (regardless that it is lowercased)

# If TAPE_DEVICE is specified, use that:
if test "$TAPE_DEVICE" ; then
    backuparchive="$TAPE_DEVICE"
    LogPrint "Using backup archive '$backuparchive'"
    return
fi

local backup_file_suffix="$BACKUP_PROG_SUFFIX$BACKUP_PROG_COMPRESS_SUFFIX"
local backup_file_name="$BACKUP_PROG_ARCHIVE$backup_file_suffix"

local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
case "$scheme" in
    (file|iso)
        # Define the output path according to the scheme
        local outputpath=$( backup_path $scheme $path )
        backuparchive="$outputpath/$backup_file_name"
        LogPrint "Using backup archive '$backuparchive'"
        return
        ;;
    (tape)
        # TODO: Check if that case is really needed.
        # Perhaps prep/default/030_translate_tape.sh does already all what is needed.
        backuparchive=$path
        LogPrint "Using backup archive '$backuparchive'"
        return
        ;;
esac

local backup_directory=$BUILD_DIR/outputfs/$NETFS_PREFIX

# Normal (i.e. non-incremental) backup:
if [ "$BACKUP_TYPE" != "incremental" ] ; then
    backuparchive="$backup_directory/$backup_file_name"
    # In case of normal (i.e. non-incremental) backup there is only one restore archive
    # and its name is the same as the backup archive (usually 'backup.tar.gz'):
    RESTORE_ARCHIVES=( "$backuparchive" )
    LogPrint "Using backup archive '$backup_file_name'"
    return
fi

# Incremental backup:
# Incremental backup only works for the NETFS backup method
# and only with the 'tar' backup program:
if ! test "NETFS" = "$BACKUP" -a "tar" = "$BACKUP_PROG" ; then
    Error "BACKUP_TYPE=incremental only works with BACKUP=NETFS and BACKUP_PROG=tar"
fi
# Incremental backup and keeping old backup contradict each other (mutual exclusive)
# so that NETFS_KEEP_OLD_BACKUP_COPY must not be 'true' in case of incremental backup:
if test "$NETFS_KEEP_OLD_BACKUP_COPY" ; then
    NETFS_KEEP_OLD_BACKUP_COPY=""
    LogPrint "Disabled NETFS_KEEP_OLD_BACKUP_COPY because BACKUP_TYPE=incremental does not work with that"
fi
# For incremental backup some date values (weekday, YYYY-MM-DD, HHMM) are needed
# that must be consistent for one single point of the current time which means
# one cannot call the 'date' command several times because then there would be
# a small probability that e.g. weekday, YYYY-MM-DD, HHMM do not match
# one single point in time (in particular when midnight passes in between).
# Therefore the output of one single 'date' call is storend in an array and
# the array elements are then assinged to individual variables as needed:
local current_date_output=( $( date '+%a %Y-%m-%d %H%M' ) )
local current_weekday="${current_date_output[0]}"
local current_yyyy_mm_dd="${current_date_output[1]}"
local current_hhmm="${current_date_output[2]}"
# The date 7 days ago is needed to check if the latest full backup is too old.
# When the latest full backup is more than 7 days ago a new full backup is made.
# This separated call of the 'date' command which is technically needed because is is
# for another point in time (7 days ago) is run after the above call of the 'date'
# command for the current time to be on the safe side when midnight passes in between
# both 'date' commands which would then result that a new full backup is made
# when the latest full backup is basically right now 7 days ago because the stored
# date of the latest full backup is the current date at the time when it was made.
# Example:
# The latest full backup was made on Sunday January 10 in 2016 (just before midnight).
# One week later this script runs again while midnight passes between the two 'date' calls
# so that current_date_output[@]="Sun 2016-01-17 0000" (still Sunday January 17 in 2016)
# and yyyymmdd_7_days_ago=20160111 (already Monday January 11 in 2016), then
# Sunday January 10 is older than Monday January 11 so that a new full backup is made:
local yyyymmdd_7_days_ago=$( date '+%Y%m%d' --date='7 days ago' )
# The full backup file name is of the form YYYY-MM-DD-HHMM-F.tar.gz
# where the 'F' denotes a full backup:
local full_backup_marker="F"
# The incremental backup file name is of the form YYYY-MM-DD-HHMM-I.tar.gz
# where the 'I' denotes an incremental backup:
local incremental_backup_marker="I"
# In case of incremental backup the RESTORE_ARCHIVES contains
# first the latest full backup file and then each incremental backup
# in the ordering how they must be restored.
# For example when the latest full backup was made on Sunday
# plus each subsequent weekday a separated incremental backup was made,
# then during a "rear recover" on Wednesday morning
# first the full backup from Sunday has to be restored,
# then the incremental backup from Monday, and
# finally the incremental backup from Tuesday.
# Here 'find /path/to/dir -name '*.tar.gz' | sort' is used because
# one cannot use bash globbing via commands like 'ls /path/to/dir/*.tar.gz'
# because /usr/sbin/rear sets the nullglob bash option which leads to plain 'ls'
# when '/path/to/dir/*.tar.gz' matches nothing (i.e. when no backup file exists)
# so that then plain 'ls' would result nonsense.
# First get the latest full backup:
local date_time_glob_regex="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]-"
local full_backup_glob_regex="$date_time_glob_regex$full_backup_marker$backup_file_suffix"
local full_or_incremental_backup_glob_regex="$date_time_glob_regex[$full_backup_marker$incremental_backup_marker]$backup_file_suffix"
local latest_full_backup=$( find $backup_directory -name "$full_backup_glob_regex" | sort | tail -n1 )
if test "$latest_full_backup" ; then
    # When a latest full backup is found use that plus all later incremental backups for restore:
    local latest_full_backup_file_name=$( basename $latest_full_backup )
    # The following command is a bit tricky:
    # It lists all YYYY-MM-DD-HHMM-F.tar.gz and all YYYY-MM-DD-HHMM-I.tar.gz files in the backup directory and sorts them
    # and finally it outputs only those that match the latest full backup file name and all what got sorted after that
    # where it is mandatory that the backup file names sort by date (i.e. date must be the leading part of the backup file names):
    RESTORE_ARCHIVES=( $( find $backup_directory -name "$full_or_incremental_backup_glob_regex" | sort | sed -n -e "/$latest_full_backup_file_name/,\$p" ) )
else
    # If no latest full backup is found (i.e. no file name matches the YYYY-MM-DD-HHMM-F.tar.gz form)
    # fall back to what is done in case of normal (i.e. non-incremental) backup
    # and hope for the best (i.e. that a backup_directory/backup_file_name actually exists).
    # In case of normal (i.e. non-incremental) backup there is only one restore archive
    # and its name is the same as the backup archive (usually 'backup.tar.gz').
    # This is only a fallback setting to be more on the safe side for "rear recover".
    # Initially for the very fist run of incremental backup during "rear mkbackup"
    # a full backup file of the YYYY-MM-DD-HHMM-F.tar.gz form will be created
    # according to the code below:
    RESTORE_ARCHIVES=( "$backup_directory/$backup_file_name" )
fi
# File that contains the YYYY-MM-DD date of the latest full backup.
# If that file does not (yet) exist a full backup is done.
# If that file already exists with a valid value (not too old), an incremental backup is done:
local latest_full_backup_date_file_name="timestamp.txt"
local latest_full_backup_date_file="$backup_directory/$latest_full_backup_date_file_name"
# File that contains the filename of the latest full backup:
local latest_full_backup_filename_file_name="basebackup.txt"
local latest_full_backup_filename_file="$backup_directory/$latest_full_backup_filename_file_name"
# A FULLBACKUPDAY value must match the 'date +%a' output (in current_weekday), see default.conf and
# quoting FULLBACKUPDAY avoids "bash: ... unary operator expected" error message if FULLBACKUPDAY is empty:
if [ $current_weekday = "$FULLBACKUPDAY" ] ; then
    # When today's weekday is FULLBACKUPDAY do a full backup in any case:
    LogPrint "Today's weekday ('$FULLBACKUPDAY') is full backup day"
    # Remove latest_full_backup_date_file to trigger a new full backup:
    rm -f $latest_full_backup_date_file
else
    # Today's weekday is not FULLBACKUPDAY (or FULLBACKUPDAY is empty):
    if [ ! -f $latest_full_backup_date_file ] ; then
        # When there is no latest_full_backup_date_file (e.g. initially)
        # there is nothing special to do here, just tell the user about it:
        LogPrint "No full backup date file (timestamp.txt) found, triggers full backup"
    else
        # There is a latest_full_backup_date_file.
        # Check if the latest full backup is too old:
        local latest_full_backup_date=$( cat $latest_full_backup_date_file )
        local yyyymmdd_latest_full_backup=$( echo $latest_full_backup_date | tr -d '-' )
        if [ $yyyymmdd_latest_full_backup -lt $yyyymmdd_7_days_ago ] ; then
            # Trigger a new full backup when latest full backup date is more than 7 days ago:
            LogPrint "Latest full backup date '$latest_full_backup_date' is too old (more than 7 days ago)"
            # Remove latest_full_backup_date_file to trigger a new full backup:
            rm -f $latest_full_backup_date_file
        else
            # When latest_full_backup_date_file exists latest_full_backup_filename_file must also exist:
            if [ ! -f $latest_full_backup_filename_file ] ; then
                # Trigger a new full backup when latest_full_backup_filename_file is missing:
                LogPrint "Latest full backup file name file (basebackup.txt) missing, triggering full backup"
                # Remove latest_full_backup_date_file to trigger a new full backup:
                rm -f $latest_full_backup_date_file
            else
                # When latest_full_backup_date_file and latest_full_backup_filename_file exist
                # verify that the matching full backup file actually exists:
                local latest_full_backup_filename=$( cat $latest_full_backup_filename_file )
                local latest_full_backup_file="$backup_directory/$latest_full_backup_filename"
                if [ ! -f $latest_full_backup_file] ; then
                    # Trigger a new full backup when the latest full backup file is missing:
                    LogPrint "Latest full backup file ($latest_full_backup_filename) not found, triggering full backup"
                    # Remove latest_full_backup_date_file to trigger a new full backup:
                    rm -f $latest_full_backup_date_file
                else
                    # When latest_full_backup_date_file and latest_full_backup_filename_file
                    # and latest_full_backup_file exist, an incremental backup will be done.
                    # There is nothing special to do here, just tell the user about it:
                    LogPrint "Full backup files found (timestamp.txt, basebackup.txt, $latest_full_backup_filename), doing incremental backup"
                fi
            fi
        fi
    fi
fi
# The actual work (setting the right stuff):
if [ -f $latest_full_backup_date_file ] ; then
    local incremental_backup_file_name="$current_yyyy_mm_dd-$current_hhmm-$incremental_backup_marker$backup_file_suffix"
    backuparchive="$backup_directory/$incremental_backup_file_name"
    BACKUP_PROG_X_OPTIONS="$BACKUP_PROG_X_OPTIONS --newer=$latest_full_backup_date -V $latest_full_backup_filename"
    LogPrint "Performing incremental backup using backup archive '$incremental_backup_file_name'"
else
    local full_backup_file_name="$current_yyyy_mm_dd-$current_hhmm-$full_backup_marker$backup_file_suffix"
    backuparchive="$backup_directory/$full_backup_file_name"
    # Create latest_full_backup_date_file and latest_full_backup_filename_file in TMP_DIR because
    # initially (i.e. for the very first run of "rear mkbackup") there is not yet the
    # backup_directory (it is created later by output/default/200_make_prefix_dir.sh) and
    # those files will later be copied into the backup_directory by output/default/950_copy_result_files.sh
    # (see see https://github.com/rear/rear/pull/1066):
    echo "$current_yyyy_mm_dd" >$TMP_DIR/$latest_full_backup_date_file_name
    echo "$full_backup_file_name" >$TMP_DIR/$latest_full_backup_filename_file_name
    BACKUP_PROG_X_OPTIONS="$BACKUP_PROG_X_OPTIONS -V $full_backup_file_name"
    LogPrint "Performing full backup using backup archive '$full_backup_file_name'"
fi

