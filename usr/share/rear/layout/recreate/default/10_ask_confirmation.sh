# Ask the user to confirm the generated script is ok

if [[ -z "$MIGRATION_MODE" ]]; then
    return 0
fi

LogPrint "Please confirm that '$LAYOUT_CODE' is as you expect."
Print ""

choices=(
    "View restore script (diskrestore.sh)"
    "Edit restore script (diskrestore.sh)"
    "Go to Rear shell"
    "Continue recovery"
    "Abort Rear"
)

select choice in "${choices[@]}"; do
    case "$REPLY" in
        (1) less $LAYOUT_CODE;;
        (2) vi $LAYOUT_CODE;;
        (3) rear_shell "" "cd $VAR_DIR/layout/
vi $LAYOUT_CODE
less $LAYOUT_CODE
";;
        (4) break;;
        (5) break;;
    esac

    # Reprint menu options when returning from less, shell or vi
    Print ""
    for (( i=1; i <= ${#choices[@]}; i++ )); do
        Print "$i) ${choices[$i-1]}"
    done
done 2>&1

Log "User selected: $REPLY) ${choices[$REPLY-1]}"

if (( REPLY == ${#choices[@]} )); then
    restore_backup $LAYOUT_FILE
    Error "User aborted Rear recovery. See $LOGFILE for details."
fi

chmod +x $LAYOUT_CODE
