
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
        # with a trailing space (looks better in user messages):
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
        if test -b "$disk_to_be_wiped" ; then
            # Write-protection for the disks in DISKS_TO_BE_WIPED
            # cf. https://github.com/rear/rear/pull/2703#issuecomment-979928423
            if is_write_protected "$disk_to_be_wiped" ; then
                DebugPrint "Excluding $disk_to_be_wiped to be wiped ($disk_to_be_wiped is write-protected)"
                continue
            fi
            # Have a trailing space delimiter to get e.g. disks_to_be_wiped="/dev/sda /dev/sdb "
            # with a trailing space (looks better in user messages):
            disks_to_be_wiped+="$disk_to_be_wiped "
        else
            # When the create_disk_label function is called for higher level block devices like RAID devices
            # e.g. as 'create_disk_label /dev/md127 gpt' the RAID device /dev/md127 is a child of a disk like /dev/sdc
            # or the RAID device /dev/md127 is a child of a partition like /dev/sdc1 that is a child of the disk /dev/sdc
            # so we need to find out the parent disk of the RAID device. Because the RAID device does not (yet) exist
            # in the currently running ReaR recovery system we check disklayout.conf that tells about the original system
            # but at this point here the devices in disklayout.conf are already migrated to what they are on the recovery system
            # so we can check disklayout.conf what the parent disk of the RAID device is on the current recovery system,
            # cf. the code in layout/prepare/GNU/Linux/120_include_raid_code.sh
            local raid raiddevice options
            read raid raiddevice options < <(grep "^raid $disk_to_be_wiped " "$LAYOUT_FILE")
            if ! test "$raiddevice" = "$disk_to_be_wiped" ; then
                # Continue with the next disk_to_be_wiped when the current one is no RAID device:
                DebugPrint "Skipping $disk_to_be_wiped to be wiped ($disk_to_be_wiped does not exist as block device)"
                continue
            else
                DebugPrint "RAID device $raiddevice does not exist - trying to determine its parent disks"
            fi
            local component_devices=()
            local option
            for option in $options ; do
                case "$option" in
                    (devices=*)
                        # E.g. when option is "devices=/dev/sda,/dev/sdb,/dev/sdc"
                        # then ${option#devices=} is "/dev/sda,/dev/sdb,/dev/sdc"
                        # so that echo ${option#devices=} | tr ',' ' '
                        # results "/dev/sda /dev/sdb /dev/sdc"
                        component_devices=( $( echo ${option#devices=} | tr ',' ' ' ) )
                        ;;
                esac
            done
            local component_device parent_device added_parent_device="no"
            for component_device in "${component_devices[@]}" ; do
                # component_device is a disk like /dev/sdc or a partition like /dev/sdc1 (cf. above)
                # so we get the parent device of it (the parent of a disk will be the disk itself)
                # cf. the code of the function write_protection_ids() in lib/write-protect-functions.sh
                # Older Linux distributions do not contain lsblk (e.g. SLES10)
                # and older lsblk versions do not support the output column PKNAME
                # so we ignore lsblk failures and error messages
                # and we skip empty lines in the output via 'awk NF'
                # and we use only the topmost reported PKNAME.
                # For example in a recovery system with RAID1 of /dev/sda and /dev/sdb
                #   # lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE                
                #   NAME        KNAME     PKNAME   TYPE FSTYPE
                #   /dev/sda    /dev/sda           disk linux_raid_member
                #   /dev/sdb    /dev/sdb           disk linux_raid_member
                #   /dev/sdc    /dev/sdc           disk 
                #   `-/dev/sdc1 /dev/sdc1 /dev/sdc part
                # There is no PKNAME for disks so we use KNAME (so the parent of a disk is the disk itself)
                # and we also use KNAME as fallback when lsblk does not support PKNAME and proceed bona fide
                # (so we wipe only KNAME of a partition but not its parent disk when PKNAME is not supported)
                # if parent_device is not one single word (valid device names are single words):
                parent_device="$( lsblk -inpo PKNAME "$component_device" 2>/dev/null | awk NF | head -n1 )"
                test $parent_device || parent_device="$( lsblk -inpo KNAME "$component_device" 2>/dev/null | awk NF | head -n1 )"
                # Without quoting an empty parent_device would result plain "test -b" which would (falsely) succeed:
                if test -b "$parent_device" ; then
                    # parent_device is usually a disk but in the KNAME fallback case it could be a partition:
                    DebugPrint "$parent_device is a parent of $raiddevice that should be wiped"
                    # Write-protection for the disks in DISKS_TO_BE_WIPED (see above).
                    # When parent_device is a partition the function write_protection_ids() in lib/write-protect-functions.sh
                    # also tries to determine its parent disk if possible to check the disk device in DISKS_TO_BE_WIPED:
                    if is_write_protected "$parent_device" ; then
                        DebugPrint "Excluding parent $parent_device to be wiped ($parent_device is write-protected)"
                        # Continue with the next component_device
                        continue
                    fi
                    DebugPrint "Adding parent $parent_device to be wiped ($parent_device is not write-protected)"
                    # Have a trailing space delimiter to get e.g. disks_to_be_wiped="/dev/sda /dev/sdb "
                    # with a trailing space (looks better in user messages):
                    disks_to_be_wiped+="$parent_device "
                    added_parent_device="yes"
                fi
            done
            if is_false $added_parent_device ; then
                DebugPrint "Skipping RAID device $raiddevice to be wiped (no parent disk found for it)"
            fi
        fi
    done
fi
DISKS_TO_BE_WIPED="$disks_to_be_wiped"
# The DISKS_TO_BE_WIPED string is needed in the subsequent layout/recreate/default/150_wipe_disks.sh script

# Show the user confirmation dialog in any case but when not in migration mode
# automatically proceed with less timeout USER_INPUT_INTERRUPT_TIMEOUT (by default 10 seconds)
# to avoid longer delays (USER_INPUT_TIMEOUT is by default 300 seconds) in case of unattended recovery:
local timeout="$USER_INPUT_TIMEOUT"
is_true "$MIGRATION_MODE" || timeout="$USER_INPUT_INTERRUPT_TIMEOUT"

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
    choice="$( UserInput -I WIPE_DISKS_CONFIRMATION -t "$timeout" -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
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
