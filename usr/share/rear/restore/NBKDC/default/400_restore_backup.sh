
source $VAR_DIR/recovery/nbkdc_settings

function print_hiback_encryption_help {
  local condev_ssl_enabled_setting="$1"

  if [ -z "$condev_ssl_enabled_setting" ]; then
    LogUserOutput "
It seems this restore image contains a Hiback without encrypted network
support. If you have updated your NovaStor Datacenter backup server to
8.0 or higher, and encounter failed connections to it, you may have to
disable encryption on the backup server temporarily. Ask NovaStor support
for further info.
"
  else
    local ssl_setting_natural_language
    local opposite_ssl_setting
    if [ "false" = "$condev_ssl_enabled_setting" ]; then
      ssl_setting_natural_language="disabled"
      opposite_ssl_setting="true"
    else
      ssl_setting_natural_language="enabled"
      opposite_ssl_setting="false"
    fi
    LogUserOutput "
At the time of creating this restore image Hiback network encryption was
$ssl_setting_natural_language. If you encounter problems to connect to the
backup server, change the setting '&ssl-enabled:' in $NBKDC_HIB_DIR/CONDEV on
this live environment to the opposite '$opposite_ssl_setting'.
"
  fi
}

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
"

print_hiback_encryption_help "$NBKDC_HIB_SSL_ENABLED"

LogUserOutput "
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
