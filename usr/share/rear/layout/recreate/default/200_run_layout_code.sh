#
# Run the disk layout recreation code (diskrestore.sh)
# again and again until it succeeds or the user aborts.
#
# TODO: Provide a skip option (needs thoughtful consideration)
# I <jsmeix@suse.de> think such an option is not needed in practice
# because the user can add an initial 'exit 0' line to diskrestore.sh
# that results in practice the same behaviour.
#
# TODO: Implement layout/prepare as part of a function ?
#
# TODO: Add choices as in layout/prepare/default/500_confirm_layout_file.sh
#  "View disk layout ($LAYOUT_FILE)"
#  "Edit disk layout ($LAYOUT_FILE)"
# and for the latter choice some code like
#   If disklayout.conf has changed, generate new diskrestore.sh
#     if (( $timestamp < $(stat --format="%Y" $LAYOUT_FILE) )); then
#         LogPrint "Detected changes to $LAYOUT_FILE, rebuild $LAYOUT_CODE on-the-fly."
#         SourceStage "layout/prepare" 2>>$RUNTIME_LOGFILE
#     fi
#

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $LAYOUT_CODE\nless $RUNTIME_LOGFILE" )"
wilful_input=""

unset choices
choices[0]="Rerun disk recreation script ($LAYOUT_CODE)"
choices[1]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
choices[2]="Edit disk recreation script ($LAYOUT_CODE)"
choices[3]="View original disk space usage ($original_disk_space_usage_file)"
choices[4]="Use Relax-and-Recover shell and return back to here"
choices[5]="Abort '$rear_workflow'"
prompt="The disk layout recreation script failed"
choice=""
# When USER_INPUT_LAYOUT_RUN has any 'true' value be liberal in what you accept and
# assume choices[0] 'Run disk recreation script again' was actually meant:
is_true "$USER_INPUT_LAYOUT_CODE_RUN" && USER_INPUT_LAYOUT_CODE_RUN="${choices[0]}"

unset confirm_choices
confirm_choices[0]="Confirm recreated disk layout and continue '$rear_workflow'"
confirm_choices[1]="Go back one step to redo disk layout recreation"
confirm_choices[2]="Use Relax-and-Recover shell and return back to here"
confirm_choices[3]="Abort '$rear_workflow'"
confirm_prompt="Confirm the recreated disk layout or go back one step"
confirm_choice=""
# When USER_INPUT_LAYOUT_MIGRATED_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume confirm_choices[0] 'Confirm recreated disk layout and continue' was actually meant:
is_true "$USER_INPUT_LAYOUT_MIGRATED_CONFIRMATION" && USER_INPUT_LAYOUT_MIGRATED_CONFIRMATION="${confirm_choices[0]}"

# Run the disk layout recreation code (diskrestore.sh)
# again and again until it succeeds or the user aborts:
while true ; do
    # Run LAYOUT_CODE in a sub-shell because it sets 'set -e'
    # so that it exits the running shell in case of an error
    # but that exit must not exit this running bash here:
    ( source $LAYOUT_CODE )
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
        # When LAYOUT_CODE succeeded and when not in migration mode
        # break the outer while loop and continue the "rear recover" workflow
        # which means continue with restoring the backup:
        is_true "$MIGRATION_MODE" || break
        # When LAYOUT_CODE succeeded in migration mode
        # let the user explicitly confirm the recreated (and usually migrated) disk layout
        # before continuing the "rear recover" workflow with restoring the backup.
        # Run an inner while loop with a user dialog so that the user can inspect the recreated disk layout
        # and perhaps even manually fix the recreated disk layout if it is not what the user wants
        # (e.g. by using the Relax-and-Recover shell and returning back to this user dialog):
        while true ; do
            confirm_choice="$( UserInput -I LAYOUT_MIGRATED_CONFIRMATION -p "$confirm_prompt" -D "${confirm_choices[0]}" "${confirm_choices[@]}" )" && wilful_input="yes" || wilful_input="no"
            case "$confirm_choice" in
                (${confirm_choices[0]})
                    # Confirm recreated disk layout and continue:
                    is_true "$wilful_input" && LogPrint "User confirmed recreated disk layout" || LogPrint "Continuing with recreated disk layout by default"
                    # Break the outer while loop and continue with restoring the backup:
                    break 2
                    ;;
                (${confirm_choices[1]})
                    # Go back one step to redo disk layout recreation:
                    # Only break the inner while loop (i.e. this user dialog loop)
                    # and  continue with the next user dialog below:
                    break
                    ;;
                (${confirm_choices[2]})
                    # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    rear_shell "" "$rear_shell_history"
                    ;;
                (${confirm_choices[3]})
                    abort_recreate
                    Error "User did not confirm the recreated disk layout but aborted '$rear_workflow' in ${BASH_SOURCE[0]}"
                    ;;
            esac
        done
    fi
    # Run an inner while loop with a user dialog so that the user can fix things when LAYOUT_CODE failed.
    # Such a fix does not necessarily mean the user must change the diskrestore.sh script.
    # The user might also fix things by only using the Relax-and-Recover shell.
    while true ; do
        choice="$( UserInput -I LAYOUT_CODE_RUN -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
        case "$choice" in
            (${choices[0]})
                # Rerun disk recreation script:
                is_true "$wilful_input" && LogPrint "User reruns disk recreation script" || LogPrint "Rerunning disk recreation script by default"
                # Only break the inner while loop (i.e. the user dialog loop):
                break
                ;;
            (${choices[1]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
                ;;
            (${choices[2]})
                # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                vi $LAYOUT_CODE 0<&6 1>&7 2>&8
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
done

