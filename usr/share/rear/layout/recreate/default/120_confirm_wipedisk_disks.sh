
# Skip it when the user has explicitly specified to not wipe disks:
is_false "$DISKS_TO_BE_WIPED" && return 0

# In migration mode let the user confirm the disks
# that will be completely wiped (as far as possible)
# so that the disk layout recreation code (diskrestore.sh)
# can run on clean disks that behave like pristine new disks.
LogPrint "Determining disks to be wiped ..."

local disk_to_be_wiped
local disks_to_be_wiped=""
if test "$DISKS_TO_BE_WIPED" ; then
    # If the user has specified DISKS_TO_BE_WIPED (i.e. when it is not empty)
    # use only those that actually exist as block devices in the recovery system:
    for disk_to_be_wiped in $DISKS_TO_BE_WIPED ; do
        # 'test -b' succeeds when there is no argument but fails when the argument is empty:
        test -b "$disk_to_be_wiped" || continue
        # Write-protection for the disks in DISKS_TO_BE_WIPED
        # cf. https://github.com/rear/rear/pull/2703#issuecomment-979928423
        if is_write_protected "$disk_to_be_wiped" ; then
          LogPrint "Excluding $disk_to_be_wiped from DISKS_TO_BE_WIPED ($disk_to_be_wiped is write-protected)"
          continue
        fi
        # Have a trailing space delimiter to get e.g. disks_to_be_wiped="/dev/sda /dev/sdb "
        # same as DISKS_TO_BE_WIPED (cf. below) with a trailing space (looks better in user messages):
        disks_to_be_wiped+="$disk_to_be_wiped "
    done
else
    # When the user has not specified DISKS_TO_BE_WIPED use an automatism:
    # The disks that will be completely overwritten are those disks
    # where in diskrestore.sh the create_disk_label function is called
    # (the create_disk_label function calls "parted -s $disk mklabel $label")
    # for example like
    #   create_disk_label /dev/sda gpt
    #   create_disk_label /dev/sdb msdos
    #   create_disk_label /dev/md127 gpt
    # so in this example DISKS_TO_BE_WIPED="/dev/sda /dev/sdb /dev/md127 "
    DISKS_TO_BE_WIPED="$( grep '^ *create_disk_label /dev/' $LAYOUT_CODE | grep -o '/dev/[^ ]*' | sort -u | tr -s '[:space:]' ' ' )"
    DebugPrint "Disks to be completely overwritten: $DISKS_TO_BE_WIPED"
    # The above automatism cannot work when the create_disk_label function is called
    # for higher level block devices like RAID devices e.g. as 'create_disk_label /dev/md127 gpt'
    # that do not exist as disks on the bare hardware or on a bare virtual machine:
    for disk_to_be_wiped in $DISKS_TO_BE_WIPED ; do
        # 'test -b' succeeds when there is no argument but fails when the argument is empty:
        if ! test -b "$disk_to_be_wiped" ; then
          DebugPrint "Skipping $disk_to_be_wiped to be wiped ($disk_to_be_wiped does not exist as block device)"
          continue
        fi
        # Write-protection for the disks in DISKS_TO_BE_WIPED
        # cf. https://github.com/rear/rear/pull/2703#issuecomment-979928423
        if is_write_protected "$disk_to_be_wiped" ; then
          DebugPrint "Excluding $disk_to_be_wiped to be wiped ($disk_to_be_wiped is write-protected)"
          continue
        fi
        # Have a trailing space delimiter to get e.g. disks_to_be_wiped="/dev/sda /dev/sdb "
        # same as DISKS_TO_BE_WIPED (cf. below) with a trailing space (looks better in user messages):
        disks_to_be_wiped+="$disk_to_be_wiped "
    done
fi
DISKS_TO_BE_WIPED="$disks_to_be_wiped"
# The DISKS_TO_BE_WIPED string is needed in the subsequent layout/recreate/default/150_wipe_disks.sh script

# When not in migration mode show the user confirmation dialog nevertheless
# but have a predefined user input to automatically proceed after USER_INPUT_INTERRUPT_TIMEOUT
# provided USER_INPUT_WIPE_DISKS_CONFIRMATION is not already set by the user
# so that the user can see what disks will be wiped and completely overwritten
# and needed abort with [Ctrl]+[C] (within USER_INPUT_INTERRUPT_TIMEOUT):
is_true "$MIGRATION_MODE" || test "$USER_INPUT_WIPE_DISKS_CONFIRMATION" || USER_INPUT_WIPE_DISKS_CONFIRMATION="yes"

rear_workflow="rear $WORKFLOW"
rear_shell_history="lsblk"
unset choices
choices[0]="Confirm disks to be completely overwritten and continue '$rear_workflow'"
choices[1]="Use Relax-and-Recover shell and return back to here"
choices[2]="Abort '$rear_workflow'"
prompt="Disks to be wiped: $DISKS_TO_BE_WIPED"
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
            is_true "$wilful_input" && LogPrint "User confirmed disks to be wiped" || LogPrint "Continuing '$rear_workflow' by default"
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
