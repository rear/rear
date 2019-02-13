# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This should avoid repeatedly querying Borg server, which could be slow.

borg_archive_cache_create && return

LogPrint "Failed to list Borg archive."
LogPrint "If you decide to continue, ReaR will partition your disks, but most probably will NOT be able to restore your data!"
Log "Command \"borg list $BORGBACKUP_OPT_REMOTE_PATH ${borg_dst_dev}${BORGBACKUP_REPO}\" returned: "
borg_list

rear_workflow="rear $WORKFLOW"

unset choices
choices[0]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
choices[1]="Use Relax-and-Recover shell and return back to here"
choices[2]="Continue '$rear_workflow'"
choices[3]="Abort '$rear_workflow'"

prompt="Make Borg archive manually accessible"
choice=""
wilful_input=""

while true ; do
    # Read user input.
    choice="$( UserInput -I BORGBACKUP_CONTINUE_WITH_RECOVER -p "$prompt" -D "${choices[3]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"

    case "$choice" in
        (${choices[0]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
        ;;
        (${choices[1]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
        ;;
        (${choices[2]})
            # Continue recovery:
            LogPrint "User confirmed to continue with '$rear_workflow'"
            break
        ;;
        (${choices[3]})
            # Abort recovery:
            abort_recreate
            is_true "$wilful_input" && Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}" || Error "Aborting '$rear_workflow' by default"
        ;;
    esac
done
