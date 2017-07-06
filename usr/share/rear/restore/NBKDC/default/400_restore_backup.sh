
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
http://www.novastor.com/help-html/dc/en-US/index.html

Verify that the backup has been restored correctly to '$TARGET_FS_ROOT'.
"

#When finished, type 'exit' to continue recovery.
#"

# Suppress the motd, as it is only confusing at this stage
#mv /etc/motd ~/.hushlogin

#rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?"

# Now we can make the motd available for further use
#mv ~/.hushlogin /etc/motd

user_input_prompt="
Have you successfully restored the backup to $TARGET_FS_ROOT ?
Are you ready ro continue recovery? (y/n)"

while true ; do
    # Restoring the backup may take arbitrary long time so that with explicit '-t 0' it wait endlessly for user input:
    if is_true "$( UserInput -t 0 -p "$user_input_prompt" )" ; then
        LogUserOutput "Done with restore. Continuing recovery."
        break
    fi
done

# continue with restore scripts
