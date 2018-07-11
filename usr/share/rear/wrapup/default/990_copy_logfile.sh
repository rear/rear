#
# Copy the logfile and other recovery related files to the recovered system,
# at least the part of the logfile that has been written till now.
#

# The following code is only meant to be used for the 'recover' workflow
# and its partial workflows 'layoutonly' and 'restoreonly'
# cf. https://github.com/rear/rear/issues/987
# and https://github.com/rear/rear/issues/1088
recovery_workflows=( "recover" "layoutonly" "restoreonly" )
IsInArray $WORKFLOW ${recovery_workflows[@]} || return 0

# Copy the logfile:
# Usually RUNTIME_LOGFILE=/var/log/rear/rear-$HOSTNAME.log
# The RUNTIME_LOGFILE name is set by the main script from LOGFILE in default.conf
# but later user config files are sourced in the main script where LOGFILE can be set different
# so that the user config LOGFILE basename is used as final logfile name:
final_logfile_name=$( basename $LOGFILE )
recover_log_dir=$LOG_DIR/recover
recovery_system_recover_log_dir=$TARGET_FS_ROOT/$recover_log_dir
# Create the directories with mode 0700 (rwx------) so that only root can access files and subdirectories therein
# because in particular logfiles could contain security relevant information.
# It is no real error when the following exit tasks fail so that they return 'true' in any case:
copy_log_file_exit_task="mkdir -p -m 0700 $recovery_system_recover_log_dir && cp -p $RUNTIME_LOGFILE $recovery_system_recover_log_dir/$final_logfile_name || true"
# To be backward compatible with where to the logfile was copied before
# have it as a symbolic link that points to where the logfile actually is:
# ( "roots" in recovery_system_roots_home_dir means root's but ' in a variable name is not so good ;-)
recovery_system_roots_home_dir=$TARGET_FS_ROOT/root
test -d $recovery_system_roots_home_dir || mkdir $verbose -m 0700 $recovery_system_roots_home_dir >&2
ln -s $recover_log_dir/$final_logfile_name $recovery_system_roots_home_dir/rear-$( date -Iseconds ).log || true

# Copy backup restore related files (in particular the backup restore log file) if exists.
# This will be done as the last one of the exit tasks of this script because
# the exit tasks are executed in reverse ordering of how AddExitTask is called
# (see AddExitTask in _input-output-functions.sh) the ordering of how AddExitTask is called
# must begin with the to-be-last-run exit task and end with the to-be-first-run exit task:
if test "$( echo $VAR_DIR/restore/* )" ; then
    # Using 'mkdir -p' primarily because that causes no error if the directory already exists
    # cf. https://github.com/rear/rear/pull/1803#discussion_r187299984
    copy_restore_log_exit_task="mkdir -p $recovery_system_recover_log_dir/restore && cp -pr $VAR_DIR/restore/* $recovery_system_recover_log_dir/restore || true"
    AddExitTask "$copy_restore_log_exit_task"
fi

# Do not copy layout and recovery related files for the 'restoreonly' workflow:
if ! test $WORKFLOW = "restoreonly" ; then
    # Using 'mkdir -p' primarily because that causes no error if one of the directories already exists
    # cf. https://github.com/rear/rear/pull/1803#discussion_r187300107
    copy_layout_files_exit_task="mkdir -p $recovery_system_recover_log_dir/layout && cp -pr $VAR_DIR/layout/* $recovery_system_recover_log_dir/layout || true"
    copy_recovery_files_exit_task="mkdir -p $recovery_system_recover_log_dir/recovery && cp -pr $VAR_DIR/recovery/* $recovery_system_recover_log_dir/recovery || true"
    AddExitTask "$copy_recovery_files_exit_task"
    AddExitTask "$copy_layout_files_exit_task"
fi

# Finally add the copy_log_file_exit_task (to be done first):
AddExitTask "$copy_log_file_exit_task"

