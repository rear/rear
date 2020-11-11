#
# In migration mode let the user confirm the disks
# that will be completely wiped (as far as possible)
# so that the disk layout recreation code (diskrestore.sh)
# can run on clean disks that behave like pristine new disks.
# The disks that will be completely wiped are those disks
# where in diskrestore.sh the create_disk_label function is called
# (the create_disk_label function calls "parted -s $disk mklabel $label")
# for example like
#   create_disk_label /dev/sda gpt
#   create_disk_label /dev/sdb msdos
# so in this example DISKS_TO_BE_WIPED="/dev/sda /dev/sdb"
DISKS_TO_BE_WIPED="$( grep '^ *create_disk_label /dev/' $LAYOUT_CODE | grep -o '/dev/[^ ]*' | sort -u | tr -s '[:space:]' ' ' )"

# The DISKS_TO_BE_WIPED string is needed in any case
# in the subsequent layout/recreate/default/150_wipe_disks.sh script
# so skip this user dialog if not in migration mode after the DISKS_TO_BE_WIPED string was set:
is_true "$MIGRATION_MODE" || return 0

rear_workflow="rear $WORKFLOW"
rear_shell_history="lsblk"
unset choices
choices[0]="Confirm disks to be completely overwritten and continue '$rear_workflow'"
choices[1]="Use Relax-and-Recover shell and return back to here"
choices[2]="Abort '$rear_workflow'"
prompt="Disks to be overwritten: $DISKS_TO_BE_WIPED"
choice=""
wilful_input=""
# When USER_INPUT_WIPE_DISKS_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm disk layout' was actually meant:
is_true "$USER_INPUT_WIPE_DISKS_CONFIRMATION" && USER_INPUT_WIPE_DISKS_CONFIRMATION="${choices[0]}"
while true ; do
    choice="$( UserInput -I WIPE_DISKS_CONFIRMATION -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Confirm disk that will be completely overwritten and continue:
            is_true "$wilful_input" && LogPrint "User confirmed disks to be overwritten" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[2]})
            abort_recreate
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done
