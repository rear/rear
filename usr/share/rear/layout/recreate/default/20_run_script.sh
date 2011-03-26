# Run the actual script

RESTORE_OK=
while [ -z "$RESTORE_OK" ] ; do
    (
        . $LAYOUT_CODE
    )

    if [ $? -eq 0 ] ; then
        RESTORE_OK=y
    else
        LogPrint "An error has been detected during restore. See $LOGFILE for details."
        LogPrint "You can fix the error in $LAYOUT_CODE and Retry or choose Abort."
        LogPrint "Only code that failed will be rerun when choosing Retry."
        
        select choice in "Retry" "Abort" ; do
            if [ "$choice" = "Retry" ] || [ "$choice" = "Abort" ] ; then
                break;
            fi
        done 2>&1
        
        if [ "$choice" = "Abort" ] ; then
            abort_recreate
        
            Error "There was an error restoring the system layout. See $LOGFILE for details."
        fi
        
    fi
done
