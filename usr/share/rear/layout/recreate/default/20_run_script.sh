# Run the actual script

RESTORE_OK=
while [[ -z "$RESTORE_OK" ]]; do
    (
        . $LAYOUT_CODE
    )

    if (( $? == 0 )); then
        RESTORE_OK=y
    else
        # TODO: Provide a skip option (needs torough consideration)
        # FIXME: Implement layout/prepare as part of a function ?
        choices=(
            "View Rear log"
            "Go to Rear shell"
#            "Edit disk layout (disklayout.conf)"
            "Edit restore script (diskrestore.sh)"
            "Continue restore script"
            "Abort Rear"
        )

        timestamp=$(stat --format="%Y" $LAYOUT_CODE)
        select choice in "${choices[@]}"; do
#            timestamp=$(stat --format="%Y" $LAYOUT_FILE)
            case "$REPLY" in
                (1) less $LOGFILE;;
                (2) rear_shell;;
#                (3) vi $LAYOUT_FILE;;
                (3) vi $LAYOUT_CODE;;
                (4) if (( $timestamp < $(stat --format="%Y" $LAYOUT_CODE) )); then
                        break
                    else
                        Print "Script $LAYOUT_CODE has not been changed, restarting has no impact."
                    fi
                    ;;
                (5) break;;
            esac

            # If disklayout.conf has changed, generate new diskrestore.sh
#            if (( $timestamp < $(stat --format="%Y" $LAYOUT_FILE) )); then
#                LogPrint "Detected changes to $LAYOUT_FILE, rebuild $LAYOUT_CODE on-the-fly."
#                SourceStage "layout/prepare" 2>>$LOGFILE
#            fi

            # Reprint menu options when returning from less, shell or vi
            Print ""
            for (( i=1; i <= ${#choices[@]}; i++ )); do
                Print "$i) ${choices[$i-1]}"
            done
        done 2>&1

        Log "User selected: $REPLY) ${choices[$REPLY-1]}"

        if (( REPLY == ${#choices[@]} )); then
            abort_recreate

            Error "There was an error restoring the system layout. See $LOGFILE for details."
        fi
    fi
done
