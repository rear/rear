
source $VAR_DIR/recovery/nbkdc_settings

procpid=$(ps -e | grep rcmd-executor | grep -v grep | awk -F\  '{print $1}')
rcmdpid=$(cat /var/run/rcmd-executor.pid)

if [ -e /var/run/rcmd-executor.pid ]; then
    if [ $procpid = $rcmdpid ]; then
        LogPrint "
NovaBACKUP DataCenter Agent started ..."
    else
        Error "NovaBACKUP DataCenter Agent rcmd-executor is NOT running ...
        Please check check the logfiles
        $NBKDC_DIR/log/rcmd-executor.log and
        $NBKDC_DIR/log/rcmd-executor.service.log
        and start the agent found in $NBKDC_DIR/rcmd-executor/
        $NBKDC_DIR/rcmd-executor/rcmd-executor start
        "
    fi
fi

LogUserOutput "
The System is now ready for restore.
Start the restore task from the
NovaBACKUP DataCenter Central Management.
It is assumed that you know what is necessary
to restore - typically it will be a full backup.

Attention!
The restore target must be set to '$TARGET_FS_ROOT'.

For further documentation see the following link:
https://support.novastor.com/hc/en-us/

Verify that the backup has been restored correctly to '$TARGET_FS_ROOT'.
"

user_input_prompt="
Have you successfully restored the backup to $TARGET_FS_ROOT ?
Are you ready to continue recovery? (y/n)"

# Restoring the backup may take arbitrary long time so that with explicit '-t 0' it waits endlessly for user input.
# Automated user input via a predefined USER_INPUT_NBKDC_WAIT_UNTIL_RESTORE_SUCCEEDED variable does not make sense here
# but the UserInput function must be called with a meaningful '-I user_input_ID' option value explicitly specified.
# To avoid that a predefined USER_INPUT_NBKDC_WAIT_UNTIL_RESTORE_SUCCEEDED variable could cause harm here it is unset:
unset USER_INPUT_NBKDC_WAIT_UNTIL_RESTORE_SUCCEEDED
while true ; do
    if is_true "$( UserInput -I NBKDC_WAIT_UNTIL_RESTORE_SUCCEEDED -t 0 -p "$user_input_prompt" )" ; then
        LogUserOutput "Done with restore. Continuing recovery."
        break
    fi
done

# continue with restore scripts
