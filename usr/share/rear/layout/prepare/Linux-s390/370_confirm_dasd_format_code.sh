# adapted from 100_confirm_layout_code.sh
#
# Let the user confirm the
# DASD format code (dasdformat.sh) script.
#

is_false "$FORMAT_DASDS" && return 0

# Show the user confirmation dialog in any case but when not in migration mode
# automatically proceed with less timeout USER_INPUT_INTERRUPT_TIMEOUT (by default 30 seconds)
# to avoid longer delays (USER_INPUT_TIMEOUT is by default 300 seconds) in case of unattended recovery:
# (taken from 120_confirm_wipedisk_disks.sh)
local timeout="$USER_INPUT_TIMEOUT"
is_true "$MIGRATION_MODE" || timeout="$USER_INPUT_INTERRUPT_TIMEOUT"

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $DASD_FORMAT_CODE\nless $DASD_FORMAT_CODE" )"
unset choices
choices[0]="Confirm DASD format script and continue '$rear_workflow'"
choices[1]="Edit DASD format script ($DASD_FORMAT_CODE)"
choices[2]="View DASD format script ($DASD_FORMAT_CODE)"
choices[3]="View original disk space usage ($original_disk_space_usage_file)"
choices[4]="Confirm what is currently on the DASDs, skip formatting them and continue '$rear_workflow'"
choices[5]="Use Relax-and-Recover shell and return back to here"
choices[6]="Abort '$rear_workflow'"
prompt="Confirm or edit the DASD format script"
choice=""
wilful_input=""
# When USER_INPUT_DASD_FORMAT_CODE_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm DASD format' was actually meant:
is_true "$USER_INPUT_DASD_FORMAT_CODE_CONFIRMATION" && USER_INPUT_DASD_FORMAT_CODE_CONFIRMATION="${choices[0]}"
while true ; do
    choice="$( UserInput -I DASD_FORMAT_CODE_CONFIRMATION -t "$timeout" -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Confirm DASD format file and continue:
            is_true "$wilful_input" && LogPrint "User confirmed DASD format script" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            vi $DASD_FORMAT_CODE 0<&6 1>&7 2>&8
            ;;
        (${choices[2]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $DASD_FORMAT_CODE 0<&6 1>&7 2>&8
            ;;
        (${choices[3]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $original_disk_space_usage_file 0<&6 1>&7 2>&8
            ;;
        (${choices[4]})
            # Confirm what is on the disks and continue without formatting
            FORMAT_DASDS="false"
            ;;
        (${choices[5]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[6]})
            abort_dasd_format
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done

chmod +x $DASD_FORMAT_CODE

