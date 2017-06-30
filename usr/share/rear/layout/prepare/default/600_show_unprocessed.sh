
# Warn about missing components and for each missing component
# offer the user a way to manually add code that recreates it.

rear_workflow="rear $WORKFLOW"
rear_shell_history="$( echo -e "vi $LAYOUT_CODE\nless $LAYOUT_CODE" )"

unset choices
choices[0]="View $LAYOUT_CODE"
choices[1]="Edit $LAYOUT_CODE"
choices[2]="Go to Relax-and-Recover shell"
choices[3]="Continue '$rear_workflow'"
choices[4]="Abort '$rear_workflow'"

while read status name type junk ; do
    missing_component="$name ($type)"
    LogUserOutput "No code has been generated to recreate $missing_component.
    To recreate it manually add code to $LAYOUT_CODE or abort."
    while true ; do
        # The default user input is "Continue" to make it possible to run ReaR unattended
        # so that 'rear recover' proceeds after the timeout regardless that it probably fails
        # when the component is not recreated but perhaps it could succeed in migration mode
        # on different replacement hardware where it might be even right to simply "Continue":
        case "$( UserInput -p "Manually add code that recreates $missing_component" -D "${choices[3]}" "${choices[@]}" )" in
            (${choices[0]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $LAYOUT_CODE 0<&6 1>&7 2>&8
                ;;
            (${choices[1]})
                # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                vi $LAYOUT_CODE 0<&6 1>&7 2>&8
                ;;
            (${choices[2]})
                # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                rear_shell "" "$rear_shell_history"
                ;;
            (${choices[3]})
                # Continue with the next missing component:
                break
                ;;
            (${choices[4]})
                abort_recreate
                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                ;;
            # No default case is needed here because the 'while true' loop repeats for invalid user input.
        esac
    done
done < <(grep "^todo" "$LAYOUT_TODO")

