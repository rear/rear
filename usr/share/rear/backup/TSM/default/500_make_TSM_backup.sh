# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Exit if TSM binary cannot be found.
has_binary dsmc || Error "Can't find TSM client dsmc; Please check your configuration."

# If the TSM client is found, do an incremental backup:
backup_tsm_log=/var/lib/rear/backup_tsm_log

if [[ ! -d "$backup_tsm_log" ]]; then
    mkdir -p $v $backup_tsm_log
fi

function check_TSM_dsmc_return_code() {

    dsmc_exit_code=$1

    # When 'dsmc' results a non-zero exit code inform the user but do not abort the whole "rear recover" here
    # because it could be an unimportant reason why 'dsmc' finished with a non-zero exit code.
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
        LogUserOutput "[TSM] dsmc backup operation completed successfully"
    else
        LogUserOutput "[TSM] dsmc backup operation completed with 'dsmc' exit code $dsmc_exit_code"
        test $dsmc_exit_code -eq 4 && LogUserOutput "[TSM rc=4] dsmc backup operation completed successfully, but some files (e.g. in an exclude list) were not processed"
        test $dsmc_exit_code -eq 8 && LogUserOutput "[TSM rc=8] dsmc backup operation completed with at least one warning message (review the TSM Error Log)"
        test $dsmc_exit_code -eq 12 && LogUserOutput "[TSM rc=12] dsmc backup operation completed with at least one error message (review the TSM Error Log)"
    fi
}

# Create TSM friendly include list.
for backup_include in $(cat $TMP_DIR/backup-include.txt); do
    include_list+=("$backup_include ")
done

LogUserOutput ""
LogUserOutput "Starting Incremental Backup with TSM [ ${include_list[@]} ]"
LogUserOutput "You can follow the backup with [ tail -f ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log ]"
LC_ALL=${LANG_RECOVER} dsmc incremental \
-verbose -tapeprompt=no "${TSM_DSMC_BACKUP_OPTIONS[@]}" \
"${include_list[@]}" > "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
dsmc_exit_code=$?
check_TSM_dsmc_return_code $dsmc_exit_code

test $dsmc_exit_code -eq 12 && Error "Error during TSM backup... Check your configuration."

### Copy progress log to backup media
if cp $v "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log"; then
    LogUserOutput "TSM Backup log available: ${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log"
    LogUserOutput "Adding TSM log file to the backup"
    dsmc incremental ${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log
    dsmc_exit_code=$?

    check_TSM_dsmc_return_code $dsmc_exit_code

    if test $dsmc_exit_code -eq 12; then
        LogUserOutput "Failed to add ${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log to the backup"
    else
        LogUserOutput "${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log added to the backup"
    fi
fi
