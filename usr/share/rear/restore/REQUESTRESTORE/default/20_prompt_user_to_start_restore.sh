#
# the user has to do the main part here :-)
#
#

LogPrint "$REQUESTRESTORE_TEXT"

if [[ "$REQUESTRESTORE_COMMAND" ]]; then
    LogPrint "Use the following command to restore the backup to your system in '/mnt/local':

    $REQUESTRESTORE_COMMAND
"

    LogPrint "Please restore your backup in the provided shell, use the shell history to
access the above command and, when finished, type exit in the shell to continue
recovery.
"
    rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?" \
        "$REQUESTRESTORE_COMMAND"
else
    LogPrint "Please restore your backup in the provided shell and, when finished, type exit
in the shell to continue recovery."

    rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?"
fi
