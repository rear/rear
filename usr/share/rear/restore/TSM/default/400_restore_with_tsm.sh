
# Restore files with TSM.
# This is done for each filespace.
local num=0
local filespace=""
local dsmc_exit_code=0
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    # Make sure filespace has a trailing / (for dsmc):
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    LogUserOutput "Restoring TSM filespace $filespace"
    Log "Running 'LC_ALL=$LANG_RECOVER dsmc restore $filespace $TARGET_FS_ROOT/$filespace -subdir=yes -replace=all -tapeprompt=no ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    # Regarding usage of '0<&6 1>&7 2>&8' see "What to do with stdin, stdout, and stderr" in https://github.com/rear/rear/wiki/Coding-Style
    LC_ALL=$LANG_RECOVER dsmc restore "$filespace" "$TARGET_FS_ROOT/$filespace" -subdir=yes -replace=all -tapeprompt=no "${TSM_DSMC_RESTORE_OPTIONS[@]}" 0<&6 1>&7 2>&8
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
        LogUserOutput "Restoring TSM filespace $filespace completed successfully"
    else
        LogUserOutput "Restoring TSM filespace $filespace completed with 'dsmc restore' exit code $dsmc_exit_code"
        test $dsmc_exit_code -eq 4 && LogUserOutput "Restoring $filespace completed successfully, but some files (e.g. in an exclude list) were not processed"
        test $dsmc_exit_code -eq 8 && LogUserOutput "Restoring $filespace completed with at least one warning message (review the TSM Error Log)"
        test $dsmc_exit_code -eq 12 && LogUserOutput "Restoring $filespace completed with at least one error message (review the TSM Error Log)"
    fi
done

