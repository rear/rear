#
# the user has to do the main part here :-)
#
#

LogPrint "$REQUESTRESTORE_TEXT"

if contains_visible_char "$REQUESTRESTORE_FINISHED_FILE" && \
    contains_visible_char "$REQUESTRESTORE_ABORT_FILE"; then

    local runtime start duration \
        check_file="$TARGET_FS_ROOT/$REQUESTRESTORE_FINISHED_FILE" \
        abort_file="$TARGET_FS_ROOT/$REQUESTRESTORE_ABORT_FILE"
    rm $verbose -f "$check_file" "$abort_file" || \
        Error "Couldn't delete restore finished file $check_file or abort file $abort_file"
    LogPrint "Waiting for $check_file file to signal when the restore is completed and recovery can proceed."
    (( start = SECONDS ))
    ProgressStart "Restoring data"
    until test -f "$check_file" ; do
        if test -f "$abort_file" ; then
            ProgressError
            Error "Restore aborted by abort file $abort_file. Reason given:$LF$(< "$abort_file"))"
        fi
        sleep "$PROGRESS_WAIT_SECONDS"
        (( duration = SECONDS - start ))
        printf -v runtime "%02d:%02d" $(( duration/60 )) $(( duration % 60 ))
        ProgressInfo "Waiting for $runtime minutes, total used storage space: $(total_target_fs_used_disk_space)"
    done
    ProgressStop
    (( duration = SECONDS - start ))
    printf -v runtime "%02d:%02d" $(( duration/60 )) $(( duration % 60 ))
    LogPrint "Restored $(total_target_fs_used_disk_space) in $runtime minutes."
    rm $verbose -f "$check_file" || Error "Couldn't delete restore finished file $check_file"
else
    if [[ "$REQUESTRESTORE_COMMAND" ]]; then
        LogPrint "Use the following command to restore the backup to your system in '$TARGET_FS_ROOT':$LF$LF$REQUESTRESTORE_COMMAND$LF"

        LogPrint "Please restore your backup in the provided shell, use the shell history to$LF" \
            "access the above command and, when finished, type exit in the shell to continue$LF" \
            "recovery.$LF"
        rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?" \
            "$REQUESTRESTORE_COMMAND"
    else
        LogPrint "Please restore your backup in the provided shell and, when finished, type exit$LF" \
            "in the shell to continue recovery."

        rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?"
    fi
fi
