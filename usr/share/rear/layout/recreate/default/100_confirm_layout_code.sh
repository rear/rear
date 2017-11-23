#
# In migration mode let the user confirm the
# disk layout recreation code (diskrestore.sh) script.
#

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $LAYOUT_CODE\nless $LAYOUT_CODE" )"
unset choices
choices[0]="Confirm disk recreation script and continue '$rear_workflow'"
choices[1]="Edit disk recreation script ($LAYOUT_CODE)"
choices[2]="View disk recreation script ($LAYOUT_CODE)"
choices[3]="View original disk space usage ($original_disk_space_usage_file)"
choices[4]="Use Relax-and-Recover shell and return back to here"
choices[5]="Abort '$rear_workflow'"
prompt="Confirm or edit the disk recreation script"
choice=""
wilful_input=""
# When USER_INPUT_LAYOUT_CODE_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm disk layout' was actually meant:
is_true "$USER_INPUT_LAYOUT_CODE_CONFIRMATION" && USER_INPUT_LAYOUT_CODE_CONFIRMATION="${choices[0]}"
while true ; do
    choice="$( UserInput -I LAYOUT_CODE_CONFIRMATION -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Confirm disk layout file and continue:
            is_true "$wilful_input" && LogPrint "User confirmed disk recreation script" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            vi $LAYOUT_CODE 0<&6 1>&7 2>&8
            ;;
        (${choices[2]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $LAYOUT_CODE 0<&6 1>&7 2>&8
            ;;
        (${choices[3]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $original_disk_space_usage_file 0<&6 1>&7 2>&8
            ;;
        (${choices[4]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[5]})
            abort_recreate
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done

chmod +x $LAYOUT_CODE

