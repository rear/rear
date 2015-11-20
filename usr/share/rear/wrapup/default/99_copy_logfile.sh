#
# copy the logfile to the recovered system, at least the part that has been written till now.
#

# The following code only works for the "recover" workflow:
if test "recover" = "$WORKFLOW" ; then
    # FIXME: The following avoids to have '/mnt/local' hardcoded at many places in the code only here.
    # The root of the filesysten tree of the to-be-recovered-system in the recovery system should be in a global variable:
    recovery_system_root=/mnt/local
    recover_log_dir=$LOG_DIR/recover
    recovery_system_recover_log_dir=$recovery_system_root/$recover_log_dir
    # Create the directories with mode 0700 (rwx------) so that only root can access files therein
    # because in particular logfiles could contain security relevant information:
    copy_log_file_exit_task="mkdir -p -m 0700 $recovery_system_recover_log_dir && cp -p $LOGFILE $recovery_system_recover_log_dir || true"
    copy_layout_files_exit_task="mkdir -m 0700 $recovery_system_recover_log_dir/layout && cp -pr $VAR_DIR/layout/* $recovery_system_recover_log_dir/layout || true"
    # To be backward compatible with whereto the logfile was copied before
    # have it as a symbolic link that points to where the logfile actually is:
    # ( roots in recovery_system_roots_home_dir means root's but ' in a variable name is not so good ;-)
    recovery_system_roots_home_dir=$recovery_system_root/root
    test -d $recovery_system_roots_home_dir || mkdir $verbose -m 0700 $recovery_system_roots_home_dir >&2
    create_compatibility_link_exit_task="ln -s $recover_log_dir/$( basename $LOGFILE ) $recovery_system_roots_home_dir/rear-$( date -Iseconds ).log || true"
    # Because the exit tasks are executed in reverse ordering of how AddExitTask is called
    # (see AddExitTask in _input-output-functions.sh) the ordering of how AddExitTask is called
    # must begin with the to-be-last-run exit task and end with the to-be-first-run exit task:
    AddExitTask "$create_compatibility_link_exit_task"
    AddExitTask "$copy_layout_files_exit_task"
    AddExitTask "$copy_log_file_exit_task"
fi

