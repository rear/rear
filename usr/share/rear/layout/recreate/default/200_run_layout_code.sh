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
#   "View disk layout ($LAYOUT_FILE)"
#   "Edit disk layout ($LAYOUT_FILE)"
# and for the latter choice some code like
#   # If disklayout.conf has changed, generate new diskrestore.sh
#   if (( $timestamp < $(stat --format="%Y" $LAYOUT_FILE) )); then
#       LogPrint "Detected changes to $LAYOUT_FILE, rebuild $LAYOUT_CODE on-the-fly."
#       SourceStage "layout/prepare" 2>>$RUNTIME_LOGFILE
#   fi
#

function lsblk_output () {
    # First try the command (which works on SLES15-SP4)
    #   lsblk -ipo NAME,KNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS
    # (for a btrfs MOUNTPOINTS shows all mountpoints where subvolumes of that btrfs are mounted
    #  while MOUNTPOINT only shows a random mounted subvolume when more than one is mounted)
    local lsblk_cols_mountpoints="NAME,KNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS"
    # then try the command (which works in general on SLES12 and SLES15)
    #   lsblk -ipo NAME,KNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINT
    local lsblk_cols_tran_type="NAME,KNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINT"
    # but on older systems (like SLES11) that do not support all that lsblk things
    # cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
    # try the simpler command
    #   lsblk -io NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT
    local lsblk_cols_generic="NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT"
    # and as fallback try 'lsblk -i' and finally try plain 'lsblk'.
    # In contrast to the lsblk commands in layout/save/GNU/Linux/100_create_layout_file.sh
    # skip PKNAME UUID WWN because they are not scrictly needed to check if things look OK
    # in particular UUID and WWN make the output lines too long for a normal terminal.
    # Show only lsblk stdout on the user's terminal (and have it also in the log file)
    # but do not show lsblk stderr on the user's terminal to avoid lsblk error messages
    # on the user's terminal when older lsblk versions fail with newer lsblk options and columns:
    { lsblk -ipo $lsblk_cols_mountpoints || lsblk -ipo $lsblk_cols_tran_type || lsblk -io $lsblk_cols_generic || lsblk -i || lsblk || echo "Cannot show disk layout (no 'lsblk' program)" ; } 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 )
}

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $LAYOUT_CODE\nless $RUNTIME_LOGFILE" )"
wilful_input=""

unset choices
choices[0]="Rerun disk recreation script ($LAYOUT_CODE)"
choices[1]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
choices[2]="Edit disk recreation script ($LAYOUT_CODE)"
choices[3]="Again wipe those disks: $DISKS_TO_BE_WIPED"
choices[4]="Show what is currently on the disks ('lsblk' block devices list)"
choices[5]="View original disk space usage ($original_disk_space_usage_file)"
choices[6]="Use Relax-and-Recover shell and return back to here"
choices[7]="Confirm what is currently on the disks and continue '$rear_workflow'"
choices[8]="Abort '$rear_workflow'"
prompt="Disk layout recreation choices"
# Do not show choice to wipe disks when whiping disks is switched off:
is_false "$DISKS_TO_BE_WIPED" && choices[3]="n/a"
# When 'barrel' is used to recreate the storage layout different choices must be shown:
BARREL_DEVICEGRAPH_DIR="$VAR_DIR/layout/barrel"
BARREL_DEVICEGRAPH_FILE=$BARREL_DEVICEGRAPH_DIR/devicegraph.xml
if is_true "$BARREL_DEVICEGRAPH" ; then
    DebugPrint "Recreating storage layout with 'barrel' devicegraph ($BARREL_DEVICEGRAPH_FILE)"
    choices[0]="Rerun 'barrel load devicegraph' ($BARREL_DEVICEGRAPH_FILE)"
    choices[2]="Switch to recreating with disk recreation script ($LAYOUT_CODE)"
fi

choice=""
# When USER_INPUT_LAYOUT_CODE_RUN has any 'true' value be liberal in what you accept and
# assume choices[0] 'Rerun disk recreation script' was actually meant
# regardless that this likely lets 'rear recover' run an endless loop
# of failed disk layout recreation attempts but ReaR must obey what the user specified
# (perhaps it is intended to let 'rear recover' loop here until an admin intervenes):
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
# or recreate storage layout with 'barrel' devicegraph
# again and again until it succeeds or the user aborts
# or the user confirms to continue with what is currently on the disks
# (the user may have setup manually what he needs via the Relax-and-Recover shell):
while true ; do
    prompt="The disk layout recreation had failed"
    if is_true "$BARREL_DEVICEGRAPH" ; then
        # See https://github.com/rear/rear/pull/2382#discussion_r417852393
        # and https://github.com/rear/rear/pull/2382#discussion_r417998820
        # and https://github.com/rear/rear/pull/2382#discussion_r418018571
        # that explains the reasoning behind the stdin stdout stderr redirection plus process substitution in
        #   COMMAND 0<&6 1>> >( tee -a $RUNTIME_LOGFILE 1>&7 ) 2>> >( tee -a $RUNTIME_LOGFILE 1>&8 )
        # which is used to show 'barrel' messges on the user's terminal and also have them in the log file.
        # It is also used to be on the save side if 'barrel' behaves interactively (regardless of '--yes').
        # Quoting "$BARREL_MAPPING_FILE" is needed because 'test -s' would falsely succeed with an empty argument:
        if test -s "$BARREL_MAPPING_FILE" ; then
            # barrel --verbose --yes --prefix /mnt/local load devicegraph --name /etc/barrel-devicegraph.xml --mapping /etc/barrel-mapping.json
            barrel --verbose --yes --prefix $TARGET_FS_ROOT load devicegraph --name $BARREL_DEVICEGRAPH_FILE --mapping $BARREL_MAPPING_FILE 0<&6 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
        else
            # barrel --verbose --yes --prefix /mnt/local load devicegraph --name /etc/barrel-devicegraph.xml
            barrel --verbose --yes --prefix $TARGET_FS_ROOT load devicegraph --name $BARREL_DEVICEGRAPH_FILE 0<&6 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
        fi
    else
        # After switching to recreating with disk recreation script
        # change choices[0] from "Run ..." to "Rerun ...":
        choices[0]="Rerun disk recreation script ($LAYOUT_CODE)"
        # Run LAYOUT_CODE in a sub-shell because it sets 'set -e'
        # so that it exits the running shell in case of an error
        # but that exit must not exit this running bash here:
        ( source $LAYOUT_CODE )
    fi
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
        prompt="Disk layout recreation had been successful"
        # When LAYOUT_CODE succeeded and when not in migration mode
        # break the outer while loop and continue the "rear recover" workflow
        # which means continue with restoring the backup:
        is_true "$MIGRATION_MODE" || break
        # When LAYOUT_CODE succeeded in migration mode
        # let the user explicitly confirm the recreated (and usually migrated) disk layout
        # before continuing the "rear recover" workflow with restoring the backup.
        # Show the recreated disk layout to the user on his terminal (and also in the log file):
        LogPrint "Recreated storage layout:"
        lsblk_output
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
    # Run an inner while loop with a user dialog so that the user can fix things
    # when LAYOUT_CODE failed or when recreating with 'barrel' devicegraph failed.
    # Such a fix does not necessarily mean the user must change
    # the diskrestore.sh script when LAYOUT_CODE failed.
    # The user might also fix things by only using the Relax-and-Recover shell
    # in particular when recreating with 'barrel' devicegraph failed and then
    # confirm what is on the disks and continue with restoring the backup
    # or abort this "rear recover" run to re-try from scratch.
    while true ; do
        choice="$( UserInput -I LAYOUT_CODE_RUN -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
        case "$choice" in
            (${choices[0]})
                if is_true "$BARREL_DEVICEGRAPH" ; then
                    # Rerun 'barrel load devicegraph':
                    is_true "$wilful_input" && LogPrint "User runs 'barrel load devicegraph'" || LogPrint "Running 'barrel load devicegraph' by default"
                else
                    # Rerun or run (after switching to recreating with disk recreation script) disk recreation script:
                    is_true "$wilful_input" && LogPrint "User runs disk recreation script" || LogPrint "Running disk recreation script by default"
                fi
                # Only break the inner while loop (i.e. the user dialog loop):
                break
                ;;
            (${choices[1]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
                ;;
            (${choices[2]})
                if is_true "$BARREL_DEVICEGRAPH" ; then
                    BARREL_DEVICEGRAPH="false"
                    choices[0]="Run disk recreation script ($LAYOUT_CODE)"
                    choices[2]="Edit disk recreation script ($LAYOUT_CODE)"
                    LogPrint "Switched to recreating with disk recreation script ($LAYOUT_CODE)"
                    is_false "$DISKS_TO_BE_WIPED" || LogPrint "You may need to wipe disks again before running the disk recreation script"
                else
                    # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    vi $LAYOUT_CODE 0<&6 1>&7 2>&8
                fi
                ;;
            (${choices[3]})
                if is_false "$DISKS_TO_BE_WIPED" ; then
                    LogPrint "Not applicable (DISKS_TO_BE_WIPED is 'false')" 
                else
                    # Again wipe disks:
                    # Before wiping disks umount all and turn off all swap
                    # because after 'barrel' recreated storage layout things are mounted and swap is on:
                    umount -v -a 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
                    swapoff -v -a 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
                    Source $SHARE_DIR/layout/recreate/default/150_wipe_disks.sh
                fi
                ;;
            (${choices[4]})
                LogPrint "This is currently on the disks:"
                lsblk_output
                ;;
            (${choices[5]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $original_disk_space_usage_file 0<&6 1>&7 2>&8
                ;;
            (${choices[6]})
                # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                rear_shell "" "$rear_shell_history"
                ;;
            (${choices[7]})
                # Confirm what is on the disks and continue:
                # Break the outer while loop and continue with restoring the backup:
                break 2
                ;;
            (${choices[8]})
                abort_recreate
                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                ;;
        esac
    done
# End of the outer while loop:
done

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f lsblk_output
