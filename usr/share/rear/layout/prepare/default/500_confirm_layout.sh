# Ask the user to confirm the layout given is final.

if [[ -z "$MIGRATION_MODE" ]]; then
    return 0
fi

LogPrint "Please confirm that '$LAYOUT_FILE' is as you expect."
Print ""

choices=(
    "View disk layout (disklayout.conf)"
    "Edit disk layout (disklayout.conf)"
    "View original disk space usage"
    "Go to Relax-and-Recover shell"
    "Continue recovery"
    "Abort Relax-and-Recover"
)

select choice in "${choices[@]}"; do
    case "$REPLY" in
        (1) less "$LAYOUT_FILE";;
        (2) vi "$LAYOUT_FILE";;
        (3) less "$VAR_DIR/layout/config/df.txt";;
        (4) rear_shell "" "cd $VAR_DIR/layout/
vi $LAYOUT_FILE
less $LAYOUT_FILE
";;
        (5) break;;
        (6) break;;
    esac

    # Reprint menu options when returning from less, shell or vi.
    Print ""
    for (( i=1; i <= ${#choices[@]}; i++ )); do
        Print "$i) ${choices[$i-1]}"
    done
done 2>&1

Log "User selected: $REPLY) ${choices[$REPLY-1]}"

if (( REPLY == ${#choices[@]} )); then
    restore_backup "$LAYOUT_FILE"
    Error "User aborted recovery. See $LOGFILE for details."
fi
