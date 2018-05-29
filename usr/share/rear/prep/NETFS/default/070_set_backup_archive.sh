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

# Normal (i.e. non-incremental/non-differential) backup:
if ! test "incremental" = "$BACKUP_TYPE" -o "differential" = "$BACKUP_TYPE" ; then
    # In case of normal (i.e. non-incremental) backup there is only one restore archive
    # and its name is the same as the backup archive (usually 'backup.tar.gz'):
    backuparchive="$backup_directory/$backup_file_name"
    LogPrint "Using backup archive '$backuparchive'"
    # This script is also run during "rear recover/restoreonly" where RESTORE_ARCHIVES must be set.
    local backup_restore_workflows=( "recover" "restoreonly" )
    if IsInArray $WORKFLOW ${backup_restore_workflows[@]} ; then
        # Only set RESTORE_ARCHIVES when the backup archive is actually accessible
        # cf. https://github.com/rear/rear/issues/1166
        if test -r "$backuparchive" ; then
            RESTORE_ARCHIVES=( "$backuparchive" )
        else
            # In case of USB backup there is the subsequent 540_choose_backup_archive.sh script
            # that shows a backup selection dialog when RESTORE_ARCHIVES is not already set.
            if test "usb" = "$scheme" ; then
                LogPrint "Backup archive '$backuparchive' not readable. Need to select another one."
            else
                Error "Backup archive '$backuparchive' not readable."
            fi
        fi
    fi
    return
fi

# Incremental or differential backup:
set -e -u -o pipefail
# Incremental or differential backup only works for the NETFS backup method
# and only with the 'tar' backup program:
if ! test "NETFS" = "$BACKUP" -a "tar" = "$BACKUP_PROG" ; then
    Error "BACKUP_TYPE incremental or differential only works with BACKUP=NETFS and BACKUP_PROG=tar"
fi
# Incremental or differential backup is currently only known to work with BACKUP_URL=nfs://.
# Other BACKUP_URL schemes may work and at least BACKUP_URL=usb:///... needs special setup
# to work with incremental or differential backup (see https://github.com/rear/rear/issues/1145):
if test "usb" = "$scheme" ; then
    # When USB_SUFFIX is set the compliance mode is used where
    # backup on USB works in compliance with backup on NFS which means
    # a fixed backup directory where incremental or differential backups work.
    # Use plain $USB_SUFFIX and not "$USB_SUFFIX" because when USB_SUFFIX contains only blanks
    # test "$USB_SUFFIX" would result true because test " " results true:
    test $USB_SUFFIX || Error "BACKUP_TYPE incremental or differential requires USB_SUFFIX for BACKUP_URL=usb"
fi
# Incremental or differential backup and keeping old backup contradict each other (mutual exclusive)
# so that NETFS_KEEP_OLD_BACKUP_COPY must not be 'true' in case of incremental or differential backup:
if test "$NETFS_KEEP_OLD_BACKUP_COPY" ; then
    NETFS_KEEP_OLD_BACKUP_COPY=""
    LogPrint "Disabled NETFS_KEEP_OLD_BACKUP_COPY because BACKUP_TYPE incremental or differential does not work with that"
fi
# For incremental or differential backup some date values (weekday, YYYY-MM-DD, HHMM) are needed
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
# The date FULLBACKUP_OUTDATED_DAYS ago is needed to check if the latest full backup is too old.
# When the latest full backup is more than FULLBACKUP_OUTDATED_DAYS ago a new full backup is made.
# This separated call of the 'date' command which is technically needed because is is
# for another point in time (e.g. 7 days ago) is run after the above call of the 'date'
# command for the current time to be on the safe side when midnight passes in between
# both 'date' commands which would then result that a new full backup is made
# when the latest full backup is basically right now FULLBACKUP_OUTDATED_DAYS ago because
# the stored date of the latest full backup is the current date at the time when it was made.
# Example (assuming FULLBACKUP_OUTDATED_DAYS=7 ):
# The latest full backup was made on Sunday January 10 in 2016 (just before midnight).
# One week later this script runs again while midnight passes between the two 'date' calls
# so that current_date_output[@]="Sun 2016-01-17 0000" (still Sunday January 17 in 2016)
# and yyyymmdd_max_days_ago=20160111 (already Monday January 11 in 2016), then
# Sunday January 10 is older than Monday January 11 so that a new full backup is made:
test "$FULLBACKUP_OUTDATED_DAYS" || FULLBACKUP_OUTDATED_DAYS="7"
local yyyymmdd_max_days_ago=$( date '+%Y%m%d' --date="$FULLBACKUP_OUTDATED_DAYS days ago" )
# Full backup file names are of the form YYYY-MM-DD-HHMM-F.tar.gz
# where the 'F' denotes a full backup:
local full_backup_marker="F"
# Incremental backup file names are of the form YYYY-MM-DD-HHMM-I.tar.gz
# where the 'I' denotes an incremental backup:
local incremental_backup_marker="I"
# Differential backup file names are of the form YYYY-MM-DD-HHMM-D.tar.gz
# where the last 'D' denotes a differential backup:
local differential_backup_marker="D"
# In case of incremental or differential backup the RESTORE_ARCHIVES contains
# first the latest full backup file.
# In case of incremental backup the RESTORE_ARCHIVES contains
# after the latest full backup file each incremental backup
# in the ordering how they must be restored.
# For example when the latest full backup was made on Sunday
# plus each subsequent weekday a separated incremental backup was made,
# then during a "rear recover" on Wednesday morning
# first the full backup from Sunday has to be restored,
# then the incremental backup from Monday, and
# finally the incremental backup from Tuesday.
# In case of differential backup the RESTORE_ARCHIVES contains
# after the latest full backup file the latest differential backup.
# For example when the latest full backup was made on Sunday
# plus each subsequent weekday a separated differential backup was made,
# then during a "rear recover" on Wednesday morning
# first the full backup from Sunday has to be restored,
# and finally the differential backup from Tuesday
# (i.e. the differential backup from Monday is skipped).
# The date format YYYY-MM-DD that is used here is crucial.
# It is the ISO 8601 format 'year-month-day' to specify a day of a year
# that is accepted by 'tar' for the '--newer' option,
# see the GNU tar manual section "Operating Only on New Files"
# at https://www.gnu.org/software/tar/manual/html_node/after.html
# and the GNU tar manual section "Calendar date items"
# at https://www.gnu.org/software/tar/manual/html_node/Calendar-date-items.html#SEC124
local date_glob_regex="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
local date_time_glob_regex="$date_glob_regex-[0-9][0-9][0-9][0-9]"
# Determine what kind of backup must be created, 'full' or 'incremental' or 'differential'
# (the empty default means it is undecided what kind of backup must be created):
local create_backup_type=""
# Code regarding creating a backup is useless during "rear recover" and
# messages about creating a backup are misleading during "rear recover":
local recovery_workflows=( "recover" "layoutonly" "restoreonly" )
if ! IsInArray $WORKFLOW ${recovery_workflows[@]} ; then
    # When today is a specified full backup day, do a full backup in any case
    # (regardless if there is already a full backup of this day):
    if IsInArray "$current_weekday" "${FULLBACKUPDAY[@]}" ; then
        create_backup_type="full"
        LogPrint "Today's weekday ('$current_weekday') is a full backup day that triggers a new full backup in any case"
    fi
fi
# Get the latest full backup (if exists):
local full_backup_glob_regex="$date_time_glob_regex-$full_backup_marker$backup_file_suffix"
# Here things like 'find /path/to/dir -name '*.tar.gz' | sort' are used because
# one cannot use bash globbing via commands like 'ls /path/to/dir/*.tar.gz'
# because /usr/sbin/rear sets the nullglob bash option which leads to plain 'ls'
# when '/path/to/dir/*.tar.gz' matches nothing (i.e. when no backup file exists)
# so that then plain 'ls' would result nonsense.
local latest_full_backup=$( find $backup_directory -name "$full_backup_glob_regex" | sort | tail -n1 )
# A latest full backup is found:
if test "$latest_full_backup" ; then
    local latest_full_backup_file_name=$( basename "$latest_full_backup" )
    # The full_or_incremental_backup_glob_regex is also needed below for non-"recover" WORKFLOWs
    # to set the right variables for creating an incremental backup:
    local full_or_incremental_backup_glob_regex="$date_time_glob_regex-[$full_backup_marker$incremental_backup_marker]$backup_file_suffix"
    # Code regarding creating a backup is useless during "rear recover" and
    # messages about creating a backup are misleading during "rear recover":
    if ! IsInArray $WORKFLOW ${recovery_workflows[@]} ; then
        # There is nothing to do here if it is already decided that
        # a full backup must be created (see "full backup day" above"):
        if ! test "full" = "$create_backup_type" ; then
            local latest_full_backup_date=$( echo $latest_full_backup_file_name | grep -o "$date_glob_regex" )
            local yyyymmdd_latest_full_backup=$( echo $latest_full_backup_date | tr -d '-' )
            # Check if the latest full backup is too old:
            if test $yyyymmdd_latest_full_backup -lt $yyyymmdd_max_days_ago ; then
                create_backup_type="full"
                LogPrint "Latest full backup date '$latest_full_backup_date' too old (more than $FULLBACKUP_OUTDATED_DAYS days ago) triggers new full backup"
            else
                # When a latest full backup is found that is not too old
                # a BACKUP_TYPE (incremental or differential) backup will be created:
                create_backup_type="$BACKUP_TYPE"
                LogPrint "Latest full backup found ($latest_full_backup_file_name) triggers $BACKUP_TYPE backup"
            fi
        fi
    else
        # This script is also run during "rear recover" where RESTORE_ARCHIVES must be set:
        case "$BACKUP_TYPE" in
            (incremental)
                # When a latest full backup is found use that plus all later incremental backups for restore:
                # The following command is a bit tricky:
                # It lists all YYYY-MM-DD-HHMM-F.tar.gz and all YYYY-MM-DD-HHMM-I.tar.gz files in the backup directory and sorts them
                # and finally it outputs only those that match the latest full backup file name and incremental backups that got sorted after that
                # where it is mandatory that the backup file names sort by date (i.e. date must be the leading part of the backup file names):
                RESTORE_ARCHIVES=( $( find $backup_directory -name "$full_or_incremental_backup_glob_regex" | sort | sed -n -e "/$latest_full_backup_file_name/,\$p" ) )
                ;;
            (differential)
                # For differential backup use the latest full backup plus the one latest differential backup for restore:
                # The following command is a bit tricky:
                # It lists all YYYY-MM-DD-HHMM-F.tar.gz and all YYYY-MM-DD-HHMM-D.tar.gz files in the backup directory and sorts them
                # then it outputs only those that match the latest full backup file name and all differential backups that got sorted after that
                # and then it outputs only the first line (i.e. the full backup) and the last line (i.e. the latest differential backup)
                # but when no differential backup exists (i.e. when only the full backup exists) the first line is also the last line
                # so that "sed -n -e '1p;$p'" outputs the full backup twice which is corrected by the final "sort -u":
                local full_or_differential_backup_glob_regex="$date_time_glob_regex-[$full_backup_marker$differential_backup_marker]$backup_file_suffix"
                RESTORE_ARCHIVES=( $( find $backup_directory -name "$full_or_differential_backup_glob_regex" | sort | sed -n -e "/$latest_full_backup_file_name/,\$p" | sed -n -e '1p;$p' | sort -u ) )
                ;;
            (*)
                BugError "Unexpected BACKUP_TYPE '$BACKUP_TYPE'"
                ;;
        esac
        # Tell the user what will be restored:
        local restore_archives_file_names=""
        for restore_archive in "${RESTORE_ARCHIVES[@]}" ; do
            restore_archives_file_names="$restore_archives_file_names $( basename "$restore_archive" )"
        done
        LogPrint "For backup restore using $restore_archives_file_names"
    fi
# No latest full backup is found:
else
    # Code regarding creating a backup is useless during "rear recover" and
    # messages about creating a backup are misleading during "rear recover":
    if ! IsInArray $WORKFLOW ${recovery_workflows[@]} ; then
        # If no latest full backup is found create one during "rear mkbackup":
        create_backup_type="full"
        LogPrint "No full backup found (YYYY-MM-DD-HHMM-F.tar.gz) triggers full backup"
    else
        # This script is also run during "rear recover" where RESTORE_ARCHIVES must be set:
        # If no latest full backup is found (i.e. no file name matches the YYYY-MM-DD-HHMM-F.tar.gz form)
        # fall back to what is done in case of normal (i.e. non-incremental/non-differential) backup
        # and hope for the best (i.e. that a backup_directory/backup_file_name actually exists).
        # In case of normal (i.e. non-incremental/non-differential) backup there is only one restore archive
        # and its name is the same as the backup archive (usually 'backup.tar.gz').
        # This is only a fallback setting to be more on the safe side for "rear recover".
        # Initially for the very fist run of incremental backup during "rear mkbackup"
        # a full backup file of the YYYY-MM-DD-HHMM-F.tar.gz form will be created.
        RESTORE_ARCHIVES=( "$backup_directory/$backup_file_name" )
        LogPrint "Using $backup_file_name for backup restore"
    fi
fi
# Code regarding creating a backup is useless during "rear recover" and
# messages about creating a backup are misleading during "rear recover":
if ! IsInArray $WORKFLOW ${recovery_workflows[@]} ; then
    # Set the right variables for creating a backup (but do not actually do anything at this point):
    case "$create_backup_type" in
        (full)
            local new_full_backup_file_name="$current_yyyy_mm_dd-$current_hhmm-$full_backup_marker$backup_file_suffix"
            backuparchive="$backup_directory/$new_full_backup_file_name"
            BACKUP_PROG_CREATE_NEWER_OPTIONS="-V $new_full_backup_file_name"
            LogPrint "Performing full backup using backup archive '$new_full_backup_file_name'"
            ;;
        (incremental)
            local new_incremental_backup_file_name="$current_yyyy_mm_dd-$current_hhmm-$incremental_backup_marker$backup_file_suffix"
            backuparchive="$backup_directory/$new_incremental_backup_file_name"
            # Get the latest latest incremental backup that is based on the latest full backup (if exists):
            local incremental_backup_glob_regex="$date_time_glob_regex-$incremental_backup_marker$backup_file_suffix"
            # First get the latest full backup plus all later incremental backups (cf. how RESTORE_ARCHIVES is set in case of incremental backup)
            # then grep only the incremental backups and from the incremental backups use only the last one (if exists):
            local latest_incremental_backup=$( find $backup_directory -name "$full_or_incremental_backup_glob_regex" | sort | sed -n -e "/$latest_full_backup_file_name/,\$p" | grep "$incremental_backup_glob_regex" | tail -n1 )
            if test "$latest_incremental_backup" ; then
                # A latest incremental backup that is based on the latest full backup is found:
                local latest_incremental_backup_file_name=$( basename $latest_incremental_backup )
                LogPrint "Latest incremental backup found ($latest_incremental_backup_file_name) that is newer than the latest full backup"
                local latest_incremental_backup_date=$( echo $latest_incremental_backup_file_name | grep -o "$date_glob_regex" )
                BACKUP_PROG_CREATE_NEWER_OPTIONS="--newer=$latest_incremental_backup_date -V $latest_incremental_backup_file_name"
                LogPrint "Performing incremental backup for files newer than $latest_incremental_backup_date using backup archive '$new_incremental_backup_file_name'"
            else
                # When there is not yet an incremental backup that is based on the latest full backup
                # the new created incremental backup must be based on the latest full backup:
                BACKUP_PROG_CREATE_NEWER_OPTIONS="--newer=$latest_full_backup_date -V $latest_full_backup_file_name"
                LogPrint "Performing incremental backup for files newer than $latest_full_backup_date using backup archive '$new_incremental_backup_file_name'"
            fi
            ;;
        (differential)
            local new_differential_backup_file_name="$current_yyyy_mm_dd-$current_hhmm-$differential_backup_marker$backup_file_suffix"
            backuparchive="$backup_directory/$new_differential_backup_file_name"
            BACKUP_PROG_CREATE_NEWER_OPTIONS="--newer=$latest_full_backup_date -V $latest_full_backup_file_name"
            LogPrint "Performing differential backup for files newer than $latest_full_backup_date using backup archive '$new_differential_backup_file_name'"
            ;;
        (*)
            BugError "Unexpected create_backup_type '$create_backup_type'"
            ;;
    esac
fi
# Go back from "set -e -u -o pipefail" to the defaults:
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

