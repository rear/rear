# Ask the user to confirm the generated script is ok

if [[ -z "$MIGRATION_MODE" ]]; then
    return 0
fi

LogPrint "Please confirm that '$LAYOUT_CODE' is as you expect."
Print ""

choices=(
    "View restore script (diskrestore.sh)"
    "Edit restore script (diskrestore.sh)"
    "View original disk space usage"
    "Go to Relax-and-Recover shell"
    "Continue recovery"
    "Abort Relax-and-Recover"
)

# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
select choice in "${choices[@]}"; do
    case "$REPLY" in
        (1) less $LAYOUT_CODE;;
        (2) vi $LAYOUT_CODE;;
        (3) less $VAR_DIR/layout/config/df.txt;;
        (4) rear_shell "" "cd $VAR_DIR/layout/
vi $LAYOUT_CODE
less $LAYOUT_CODE
";;
        (5) break;;
        (6) break;;
    esac

    # Reprint menu options when returning from less, shell or vi
    Print ""
    for (( i=1; i <= ${#choices[@]}; i++ )); do
        Print "$i) ${choices[$i-1]}"
    done
done 0<&6 1>&7 2>&8

Log "User selected: $REPLY) ${choices[$REPLY-1]}"

if (( REPLY == ${#choices[@]} )); then
    restore_backup $LAYOUT_FILE
    Error "User aborted recovery. See $RUNTIME_LOGFILE for details."
fi

chmod +x $LAYOUT_CODE
