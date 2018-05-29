
# Restore files with TSM.
# This is done for each filespace.
local num=0
local filespace=""
local dsmc_exit_code=0
local log_message=""

# Create common backup restore log file name prefix (same for each filespace):
local backup_restore_log_dir="$VAR_DIR/restore"
mkdir -p $backup_restore_log_dir
local backup_restore_log_file=""
local backup_restore_log_prefix=$BACKUP
local backup_restore_log_suffix="restore.log"
# E.g. when "rear -C 'general.conf /path/to/special.conf' recover" was called CONFIG_APPEND_FILES is "general.conf /path/to/special.conf"
# so that in particular '/' characters must be replaced in the backup restore log file (by a colon) and then
# the backup restore log file name will be like .../restore/backup.generalconf_:path:to:specialconf.:var:lib:.1234.restore.log
# It does not work with $( tr -d -c '[:alnum:]/[:space:]' <<<"$CONFIG_APPEND_FILES" | tr -s '/[:space:]' ':_' )
# because the <<<"$CONFIG_APPEND_FILES" results a trailing newline that becomes a trailing '_' character so that
# echo -n $CONFIG_APPEND_FILES (without double quotes) is used to avoid leading and trailing spaces and newlines:
test "$CONFIG_APPEND_FILES" && backup_restore_log_prefix=$backup_restore_log_prefix.$( echo -n $CONFIG_APPEND_FILES | tr -d -c '[:alnum:]/[:space:]' | tr -s '/[:space:]' ':_' )
local backup_restore_log_filespace=""

for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    LogUserOutput "Restoring TSM filespace $filespace"
    # Create backup restore log file name (a different one for each filespace).
    # Each filespace is a path like '/' or '/home/' or '/var/lib/' so that in particular '/' characters must be replaced
    # (see above why <<<"$filespace" does not work here so that a 'echo -n $filespace' pipe is also used here):
    backup_restore_log_filespace=$( echo -n $filespace | tr -d -c '[:alnum:]/[:space:]' | tr -s '/[:space:]' ':_' )
    backup_restore_log_file=$backup_restore_log_dir/$backup_restore_log_prefix.$backup_restore_log_filespace.$MASTER_PID.$backup_restore_log_suffix
    cat /dev/null >$backup_restore_log_file
    UserOutput "Filespace '$filespace' restore progress can be followed with 'tail -f $backup_restore_log_file'"
    # Make sure filespace has a trailing / (for dsmc):
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    Log "Running 'LC_ALL=$LANG_RECOVER dsmc restore $filespace $TARGET_FS_ROOT/$filespace -subdir=yes -replace=all -tapeprompt=no -errorlogname=\"$backup_restore_log_file\" ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    # Regarding things like '0<&6 1>&7 2>&8' see "What to do with stdin, stdout, and stderr" in https://github.com/rear/rear/wiki/Coding-Style
    # Both stdout and stderr are redirected into the backup restore log file
    # to have all backup restore program messages in one same log file and
    # in the right ordering because with 2>&1 both streams are correctly merged
    # cf. https://github.com/rear/rear/issues/885#issuecomment-310082587
    # which also means that in '-D' debugscript mode some 'set -x' messages of this code here
    # appear in the backup restore log file which is perfectly fine because in the normal log file
    # the above UserOutput tells via "restore progress can be followed with 'tail -f $backup_restore_log_file'"
    # where to look and it is helpful for debugging to also have the related 'set -x' messages in the same log file.
    # To be more on the safe side append to the log file '>>' instead of plain writing to it '>'
    # because when a program (bash in this case) is plain writing to the log file it can overwrite
    # output of a possibly simultaneously running process that likes to append to the log file
    # (e.g. when background processes run that also uses the log file for logging)
    # cf. https://github.com/rear/rear/issues/885#issuecomment-310308763
    LC_ALL=$LANG_RECOVER dsmc restore "$filespace" "$TARGET_FS_ROOT/$filespace" -subdir=yes -replace=all -tapeprompt=no -errorlogname=\"$backup_restore_log_file\" "${TSM_DSMC_RESTORE_OPTIONS[@]}" 0<&6 1>>"$backup_restore_log_file" 2>&1
    dsmc_exit_code=$?
    # When 'dsmc restore' results a non-zero exit code inform the user but do not abort the whole "rear recover" here
    # because it could be an unimportant reason why 'dsmc restore' finished with a non-zero exit code.
    # What usual exit codes mean see http://publib.boulder.ibm.com/tividd/td/TSMC/GC32-0787-04/en_US/HTML/ans10000117.htm
    # that reads in particular (as of this writing on Dec. 13 2017):
    #   0     All operations completed successfully.
    #   4     The operation completed successfully, but some files were not processed. There were no other errors or warnings.
    #         This return code is very common. Files are not processed for various reasons. The most common reasons are:
    #          - The file is in an exclude list.
    #          - The file was in use by another application and could not be accessed by the client.
    #          - The file changed during the operation to an extent prohibited by the copy serialization attribute.
    #   8     The operation completed with at least one warning message. For scheduled events, the status will be Completed.
    #         Review TSM Error Log (and dsmsched.log for scheduled events) to determine what warning messages were issued and to assess their impact on the operation.
    #   12    The operation completed with at least one error message (except for error messages for skipped files). For scheduled events, the status will be Failed.
    #         Review the TSM Error Log file (and dsmsched.log file for scheduled events) to determine what error messages were issued and to assess their impact
    #         on the operation. As a general rule, this return code means that the error was severe enough to prevent the successful completion of the operation.
    #         For example, an error that prevents an entire from being processed yields return code 12. When a file is not found the operation yields return code 12.
    #   other For scheduled operations where the scheduled action is COMMAND, the return code will be the return code from the command that was executed.
    #         If the return code is 0, the status of the scheduled operation will be Completed. If the return code is nonzero, then the status will be Failed.
    #         Some commands may issue a nonzero return code to indicate success. For these commands, you can avoid a Failed status by wrapping the command in a script
    #         that invokes the command, interprets the results, and exits with return code 0 if the command was successful (the script should exit with a nonzero return code
    #         if the command failed). Then ask your Tivoli Storage Manager server administrator modify the schedule definition to invoke your script instead of the command.
    #   The return code for a client macro will be the highest return code issued among the individual commands that comprise the macro.
    #   For example, suppose a macro consists of these commands: If the first command completes with return code 0; the second command completes with return code 8;
    #   and the third command completes with return code 4, the return code for the macro will be 8.
    if test $dsmc_exit_code -eq 0 ; then
        log_message="Restoring TSM filespace $filespace completed successfully"
        LogUserOutput "$log_message"
        echo "$log_message" >>"$backup_restore_log_file"
    else
        log_message="Restoring TSM filespace $filespace completed with 'dsmc restore' exit code $dsmc_exit_code"
        LogUserOutput "$log_message"
        echo "$log_message" >>"$backup_restore_log_file"
        test $dsmc_exit_code -eq 4 && log_message="Restoring $filespace completed successfully, but some files (e.g. in an exclude list) were not processed"
        test $dsmc_exit_code -eq 8 && log_message="Restoring $filespace completed with at least one warning message (review $backup_restore_log_file)"
        test $dsmc_exit_code -eq 12 && log_message="Restoring $filespace completed with at least one error message (review $backup_restore_log_file)"
        LogUserOutput "$log_message"
        echo "$log_message" >>"$backup_restore_log_file"
    fi
done

