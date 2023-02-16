# adapted from 200_run_layout_code.sh
#
# Run the DASD format code (dasdformat.sh)
# again and again until it succeeds or the user aborts.
#

function lsdasd_output () {
    lsdasd 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 )
}

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $DASD_FORMAT_CODE\nless $RUNTIME_LOGFILE" )"
wilful_input=""

unset choices
choices[0]="Rerun DASD format script ($DASD_FORMAT_CODE)"
choices[1]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
choices[2]="Edit DASD format script ($DASD_FORMAT_CODE)"
choices[3]="Show what is currently on the disks ('lsdasd' device list)"
choices[4]="View original disk space usage ($original_disk_space_usage_file)"
choices[5]="Use Relax-and-Recover shell and return back to here"
choices[6]="Confirm what is currently on the disks and continue '$rear_workflow'"
choices[7]="Abort '$rear_workflow'"
prompt="DASD format choices"

choice=""
# When USER_INPUT_DASD_FORMAT_CODE_RUN has any 'true' value be liberal in what you accept and
# assume choices[0] 'Rerun DASD format script' was actually meant
# regardless that this likely lets 'rear recover' run an endless loop
# of failed DASD format attempts but ReaR must obey what the user specified
# (perhaps it is intended to let 'rear recover' loop here until an admin intervenes):
is_true "$USER_INPUT_DASD_FORMAT_CODE_RUN" && USER_INPUT_DASD_FORMAT_CODE_RUN="${choices[0]}"

unset confirm_choices
confirm_choices[0]="Confirm recreated DASD format and continue '$rear_workflow'"
confirm_choices[1]="Go back one step to redo DASD format"
confirm_choices[2]="Use Relax-and-Recover shell and return back to here"
confirm_choices[3]="Abort '$rear_workflow'"
confirm_prompt="Confirm the recreated DASD format or go back one step"
confirm_choice=""
# When USER_INPUT_DASD_FORMAT_MIGRATED_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume confirm_choices[0] 'Confirm recreated DASD format and continue' was actually meant:
is_true "$USER_INPUT_DASD_FORMAT_MIGRATED_CONFIRMATION" && USER_INPUT_DASD_FORMAT_MIGRATED_CONFIRMATION="${confirm_choices[0]}"

# Run the DASD format code (dasdformat.sh)
# again and again until it succeeds or the user aborts
# or the user confirms to continue with what is currently on the disks
# (the user may have setup manually what he needs via the Relax-and-Recover shell):
while true ; do
    prompt="The DASD format had failed"
    # After switching to recreating with DASD format script
    # change choices[0] from "Run ..." to "Rerun ...":
    choices[0]="Rerun DASD format script ($DASD_FORMAT_CODE)"
    # Run DASD_FORMAT_CODE in a sub-shell because it sets 'set -e'
    # so that it exits the running shell in case of an error
    # but that exit must not exit this running bash here:
    ( source $DASD_FORMAT_CODE )
    # One must explicitly test whether or not $? is zero in a separated bash command
    # because with bash 3.x and bash 4.x code like
    #   # ( set -e ; cat qqq ; echo "hello" ) && echo ok || echo failed
    #   cat: qqq: No such file or directory
    #   hello
    #   ok
    # does not work as one may expect (cf. what "man bash" describes for 'set -e').
    # There is a subtle behavioural difference between bash 3.x and bash 4.x
    # when a script that has 'set -e' set gets sourced:
    # With bash 3.x the 'set -e' inside the sourced script is effective:
    #   # echo 'set -e ; cat qqq ; echo hello' >script.sh
    #   # ( source script.sh ) && echo ok || echo failed
    #   cat: qqq: No such file or directory
    #   failed
    # With bash 4.x the 'set -e' inside the sourced script gets noneffective:
    #   # echo 'set -e ; cat qqq ; echo hello' >script.sh
    #   # ( source script.sh ) && echo ok || echo failed
    #   cat: qqq: No such file or directory
    #   hello
    #   ok
    # With bash 3.x and bash 4.x testing $? in a separated bash command
    # keeps the 'set -e' inside the sourced script effective:
    #   # echo 'set -e ; cat qqq ; echo hello' >script.sh
    #   # ( source script.sh ) ; (( $? == 0 )) && echo ok || echo failed
    #   cat: qqq: No such file or directory
    #   failed
    # See also https://github.com/rear/rear/pull/1573#issuecomment-344303590
    if (( $? == 0 )) ; then
        prompt="DASD format had been successful"
        # When DASD_FORMAT_CODE succeeded and when not in migration mode
        # break the outer while loop and continue the "rear recover" workflow
        # which means continue with restoring the backup:
        is_true "$MIGRATION_MODE" || break
        # When DASD_FORMAT_CODE succeeded in migration mode
        # let the user explicitly confirm the recreated (and usually migrated) format
        # before continuing the "rear recover" workflow with restoring the backup.
        # Show the recreated DASD format to the user on his terminal (and also in the log file):
        LogPrint "Recreated DASD format:"
        lsdasd_output
        # Run an inner while loop with a user dialog so that the user can inspect the recreated DASD format
        # and perhaps even manually fix the recreated DASD format if it is not what the user wants
        # (e.g. by using the Relax-and-Recover shell and returning back to this user dialog):
        while true ; do
            confirm_choice="$( UserInput -I DASD_FORMAT_MIGRATED_CONFIRMATION -p "$confirm_prompt" -D "${confirm_choices[0]}" "${confirm_choices[@]}" )" && wilful_input="yes" || wilful_input="no"
            case "$confirm_choice" in
                (${confirm_choices[0]})
                    # Confirm recreated DASD format and continue:
                    is_true "$wilful_input" && LogPrint "User confirmed recreated DASD format" || LogPrint "Continuing with recreated DASD format by default"
                    # Break the outer while loop and continue with restoring the backup:
                    break 2
                    ;;
                (${confirm_choices[1]})
                    # Go back one step to redo DASD format:
                    # Only break the inner while loop (i.e. this user dialog loop)
                    # and  continue with the next user dialog below:
                    break
                    ;;
                (${confirm_choices[2]})
                    # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    rear_shell "" "$rear_shell_history"
                    ;;
                (${confirm_choices[3]})
                    abort_dasd_format
                    Error "User did not confirm the recreated DASD format but aborted '$rear_workflow' in ${BASH_SOURCE[0]}"
                    ;;
            esac
        done
    fi
    # Run an inner while loop with a user dialog so that the user can fix things
    # when DASD_FORMAT_CODE failed.
    # Such a fix does not necessarily mean the user must change
    # the dasdformat.sh script when DASD_FORMAT_CODE failed.
    # The user might also fix things by only using the Relax-and-Recover shell and
    # then confirm what is on the disks and continue with restoring the backup
    # or abort this "rear recover" run to re-try from scratch.
    while true ; do
        choice="$( UserInput -I DASD_FORMAT_CODE_RUN -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
        case "$choice" in
            (${choices[0]})
                # Rerun or run (after switching to recreating with DASD format script) DASD format script:
                is_true "$wilful_input" && LogPrint "User runs DASD format script" || LogPrint "Running DASD format script by default"
                # Only break the inner while loop (i.e. the user dialog loop):
                break
                ;;
            (${choices[1]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
                ;;
            (${choices[2]})
                # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                vi $DASD_FORMAT_CODE 0<&6 1>&7 2>&8
                ;;
            (${choices[3]})
                LogPrint "This is the current list of DASDs:"
                lsdasd_output
                ;;
            (${choices[4]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $original_disk_space_usage_file 0<&6 1>&7 2>&8
                ;;
            (${choices[5]})
                # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                rear_shell "" "$rear_shell_history"
                ;;
            (${choices[6]})
                # Confirm what is on the disks and continue:
                # Break the outer while loop and continue with restoring the backup:
                break 2
                ;;
            (${choices[7]})
                abort_dasd_format
                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                ;;
        esac
    done
# End of the outer while loop:
done

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f lsdasd_output
