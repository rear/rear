
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
    LogUserOutput "No code has been generated to recreate $missing_component"
    LogUserOutput "To recreate $missing_component manually add code to $LAYOUT_CODE or abort"
    while true ; do
        # The default user input is "Continue" to make it possible to run ReaR unattended
        # so that 'rear recover' proceeds after the timeout regardless that it probably fails
        # when the component is not recreated but perhaps it could succeed in migration mode
        # on different replacement hardware where it might be even right to simply "Continue".
        # Generate a runtime-specific user_input_ID so that for each missing component
        # a different user_input_ID is used for the UserInput call so that the user can specify
        # for each missing component a different predefined user input.
        # Only uppercase letters and digits are used to ensure the user_input_ID is a valid bash variable name
        # (otherwise the UserInput call could become invalid which aborts 'rear recover' with a BugError) and
        # hopefully only uppercase letters and digits are sufficient to distinguish different missing components:
        current_missing_component_alnum_uppercase="$( echo "$missing_component" | tr -d -c '[:alnum:]' | tr '[:lower:]' '[:upper:]' )"
        test "$current_missing_component_alnum_uppercase" || current_missing_component_alnum_uppercase="COMPONENT"
        user_input_ID="ADD_CODE_TO_RECREATE_MISSING_$current_missing_component_alnum_uppercase"
        case "$( UserInput -I $user_input_ID -p "Manually add code that recreates $missing_component" -D "${choices[3]}" "${choices[@]}" )" in
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

