# Run the actual script

RESTORE_OK=
while [[ -z "$RESTORE_OK" ]]; do
    (
        . $LAYOUT_CODE
    )

    if (( $? -eq 0 )); then
        RESTORE_OK=y
    else
        LogPrint "An error occured during restore. See $LOGFILE for details."
        LogPrint
        LogPrint "You can either:"
        LogPrint " - fix the error in $LAYOUT_CODE on another terminal and Retry here"
        LogPrint "   (only code-snippets that failed will be rerun when choosing Retry)"
        LogPrint " - choose Abort and fix the error in $LAYOUT_FILE and rerun 'rear recover'"

        select choice in "Retry" "Abort"; do
            if [[ "$choice" == "Retry" || "$choice" == "Abort" ]]; then
                break;
            fi
        done 2>&1

        if [[ "$choice" == "Abort" ]]; then
            abort_recreate

            Error "There was an error restoring the system layout. See $LOGFILE for details."
        fi
    fi
done
