
# Map source disks (i.e. 'disk' devices and 'multipath' devices in the LAYOUT_FILE)
# to target disks (i.e. current devices in the currently running recovery system).

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

generate_layout_dependencies

mapping_file_basename="disk_mappings"
MAPPING_FILE="$VAR_DIR/layout/$mapping_file_basename"

# Local functions that are 'unset' at the end of this script:

# Add a disk mapping from source $1 to target $2.
# Source and target should be like "sda" "cciss/c1d0".
function add_mapping () {
    echo "$1 $2" >>"$MAPPING_FILE"
}

# Return 0 if a mapping for $1 exists
# i.e. if $1 is used as source in the mapping file:
function is_mapping_source () {
    local test_source="$1"
    # When $MAPPING_FILE is empty the below command
    #   grep -v '^#' "$MAPPING_FILE"
    # would hang up endlessly without user notification
    # because that command would become
    #   grep -v '^#'
    # which reads from stdin (i.e. from the user's keyboard).
    # A non-existent mapping file means $1 is not used as source in the mapping file:
    test -f "$MAPPING_FILE" || return 1
    # Only non-commented and syntactically valid lines in the mapping file count
    # so that also an empty mapping file or when there is not at least one valid mapping
    # are considered to be completely identical mappings
    # (i.e. 'no valid mapping' means 'do not change anything' which is the identity map):
    while read source target junk ; do
        # Skip lines that have wrong syntax:
        test "$source" -a "$target" || continue
        test "$test_source" = "$source" && return 0
    done < <( grep -v '^#' "$MAPPING_FILE" )
    return 1
}

# Return 0 if $1 is used as a target in a mapping:
function is_mapping_target () {
    local test_target="$1"
    # Cf. the comments in the is_mapping_source function:
    test -f "$MAPPING_FILE" || return 1
    while read source target junk ; do
        test "$source" -a "$target" || continue
        test "$test_target" = "$target" && return 0
    done < <( grep -v '^#' "$MAPPING_FILE" )
    return 1
}

# Output the valid mappings in the mapping file
# and inform the user if there is no valid mapping:
function output_valid_mappings () {
    local valid_mapping=''
    echo 'Current disk mapping table (source => target):'
    # Cf. the comments in the is_mapping_source function:
    test -f "$MAPPING_FILE" || return 1
    while read source target junk ; do
        # Continue until a valid mapping is found:
        test "$source" -a "$target" || continue
        # A valid mapping is found:
        valid_mapping='yes'
        # The two leading spaces are an intentional indentation for better readability:
        echo "  $source => $target"
    done < <( grep -v '^#' "$MAPPING_FILE" )
    is_true $valid_mapping || echo "  There is no valid disk mapping"
}

# Output unmapped 'disk' devices and 'multipath' devices that will not be recreated:
function output_not_recreated_devices () {
    local header_lines='Currently unmapped disks and dependant devices will not be recreated\n(unless identical disk mapping and proceeding without manual configuration):'
    while read keyword device junk ; do
        # Continue until an unmapped disk device is found:
        is_mapping_source "$device" && continue
        # Output the header lines only once:
        if test "$header_lines" ; then 
            echo -e "$header_lines"
            header_lines=''
        fi
        # The get_child_components function outputs each dependant device on a new line
        # but the echo command outputs all its command line arguments on one line
        # each one separated by a single space e.g. the command
        #   echo ' ' foo $( echo -e ' bar \n baz ' )
        # results '  foo bar baz' on a single line (note the two leading spaces).
        # The two leading spaces are an intentional indentation for better readability:
        echo ' ' $device $( get_child_components "$device" )
    done < <( grep -E "^disk |^multipath " "$LAYOUT_FILE" )
}

# Start with an empty mapping file unless there is a user provided mapping file.
# If etc/rear/mappings/disk_mappings or etc/rear/mappings/disk_devices exists
# use that as mapping file where etc/rear/mappings/disk_mappings is preferred
# and etc/rear/mappings/disk_devices is only there for backward compatibility:
cat /dev/null >"$MAPPING_FILE"
for user_provided_mapping_file in $mapping_file_basename disk_devices ; do
    if test -f "$user_provided_mapping_file" ; then
        cp "$user_provided_mapping_file" "$MAPPING_FILE"
        LogPrint "Using user provided mapping file $user_provided_mapping_file"
        break
    fi
done

# Automap original 'disk' devices and 'multipath' devices in the LAYOUT_FILE
# to current block devices in the currently running recovery system:
while read keyword orig_device orig_size junk ; do
    # Continue with next original device when it is already used as source in the mapping file:
    if is_mapping_source "$orig_device" ; then
        DebugPrint "Skip automapping $orig_device (already exists as source in $MAPPING_FILE)"
        continue
    fi
    # The original device is not yet mapped (i.e. not used as source in the mapping file) so it needs to be mapped.
    # Remember when target devices get known by the "same name and same size" tests
    # that they cannot be used for recreating the current original device
    # to avoid that already excluded target devices get needlessly
    # considered again during the subsequent "same size" tests:
    excluded_target_device_names=()
    # First, try to find if there is a current disk with same name and same size as the original:
    sysfs_device_name="$( get_sysfs_name "$orig_device" )"
    current_device="/sys/block/$sysfs_device_name"
    if test -e $current_device ; then
        current_size=$( get_disk_size $sysfs_device_name )
        # The current_device (e.g. /sys/block/sda) is not a block device so that
        # its matching actual block device (e.g. /dev/sda) must be determined:
        preferred_target_device_name="$( get_device_name $current_device )"
        # Use the current one if it is of same size as the old one:
        if test "$orig_size" -eq "$current_size" ; then
            # Ensure the target device is really a block device on the replacement hardware.
            # Here the target device has same name as the original device which was a block device on the original hardware
            # but it might perhaps happen that this device name is not a block device on the replacement hardware:
            if test -b "$preferred_target_device_name" ; then
                # Do not map if the current one is already used as target in the mapping file:
                if is_mapping_target "$preferred_target_device_name" ; then
                    DebugPrint "Cannot use $preferred_target_device_name (same name and same size) for recreating $orig_device ($preferred_target_device_name already exists as target in $MAPPING_FILE)"
                    excluded_target_device_names+=( "$preferred_target_device_name" )
                else
                    # Ensure the determined target device is not write-protected:
                    if is_write_protected "$preferred_target_device_name" ; then
                        DebugPrint "Cannot use $preferred_target_device_name (same name and same size) for recreating $orig_device ($preferred_target_device_name is write-protected)"
                        excluded_target_device_names+=( "$preferred_target_device_name" )
                    else
                        add_mapping "$orig_device" "$preferred_target_device_name"
                        LogPrint "Using $preferred_target_device_name (same name and same size $current_size) for recreating $orig_device"
                        # Continue with next original device because the current one is now mapped:
                        continue
                    fi
                fi
            fi
        fi
    fi
    # If there is no current disk with same name and same size as the original
    # loop over all current block devices to find one of same size as the original:
    for current_device_path in /sys/block/* ; do
        # Continue with next block device if the current one has no queue directory:
        test -d $current_device_path/queue || continue
        # Continue with next block device if no size can be read for the current one:
        test -r $current_device_path/size || continue
        current_disk_name="${current_device_path#/sys/block/}"
        current_size=$( get_disk_size $current_disk_name )
        # The current_device_path (e.g. /sys/block/sdb) is not a block device so that
        # its matching actual block device (e.g. /dev/sdb) must be determined:
        preferred_target_device_name="$( get_device_name $current_device_path )"
        # Ensure the determined target device is really a block device (cf. above):
        test -b "$preferred_target_device_name" || continue
        # Continue with next block device if the current one is not of same size as the original:
        test "$orig_size" -eq "$current_size" || continue
        # Continue with next block device if the current one was already excluded by the "same name and same size" tests above:
        IsInArray "$preferred_target_device_name" "${excluded_target_device_names[@]}" && continue
        # Continue with next block device if the current one is already used as target in the mapping file:
        if is_mapping_target "$preferred_target_device_name" ; then
            DebugPrint "Cannot use $preferred_target_device_name (same size) for recreating $orig_device ($preferred_target_device_name already exists as target in $MAPPING_FILE)"
            continue
        fi
        # Ensure the determined target device is not write-protected (cf. above):
        if is_write_protected "$preferred_target_device_name" ; then
            DebugPrint "Cannot use $preferred_target_device_name (same size) for recreating $orig_device ($preferred_target_device_name is write-protected)"
            continue
        fi
        # The first of all current block devices with same size as the original that is not yet used as target gets used:
        add_mapping "$orig_device" "$preferred_target_device_name"
        LogPrint "Using $preferred_target_device_name (same size $current_size) for recreating $orig_device"
        # Continue the outer while loop with next original device because the current one is now mapped:
        continue 2
    done
    # The original device could not be automapped because there is
    # neither a current disk with same name and same size as the original
    # nor is there a current disk with different name but same size as the original
    # so the user must maually specify the right mapping target:
    DebugPrint "Could not automap $orig_device (no disk with same size $orig_size found)"
done < <( grep -E "^disk |^multipath " "$LAYOUT_FILE" )

# For every unmapped original 'disk' device and 'multipath' device in the LAYOUT_FILE
# let the user choose from the still unmapped disks in the currently running recovery system:
while read keyword orig_device orig_size junk ; do
    # Continue with next original device when it is already used as source in the mapping file
    # i.e. when it is already mapped to one in the currently running recovery system:
    is_mapping_source "$orig_device" && continue
    # Inform the user about the unmapped original device:
    preferred_orig_device_name="$( get_device_name $orig_device )"
    LogUserOutput "Original disk $preferred_orig_device_name does not exist (with same size) in the target system"
    # Build the set of still unmapped current disks wherefrom the user can choose:
    possible_targets=()
    # Loop over all current block devices to find appropriate ones wherefrom the user can choose:
    for current_device_path in /sys/block/* ; do
        current_device_basename="${current_device_path##*/}"
        # Do not include removable devices in the choices for the user
        # for example CDROM is removable because /sys/block/sr0/removable contains '1'
        # but a USB disk is not removable because /sys/block/sdb/removable contains '0'
        # so this condition is primarily there to skip CDROM devices
        # (in particular the device where the ReaR recovery system was booted from)
        # because we cannot test /sys/block/sr0/ro which usually contains '0'
        # because that is usually a CD/DVD-RW device that can write (depending on the medium)
        # cf. https://unix.stackexchange.com/questions/22019/how-can-i-test-whether-a-block-device-is-read-only-from-sys-or-proc
        if test "$( < $current_device_path/removable )" = "1" ; then
            Log "$current_device_basename excluded from device mapping choices (is a removable device)"
            continue
        fi
        # Do not include devices in EXCLUDE_DEVICE_MAPPING in the choices for the user.
        # One cannot use IsInArray here because EXCLUDE_DEVICE_MAPPING contains patterns
        # (e.g. "loop*" and "ram*" see default.conf) so that 'case' pattern matching is used:
        for pattern in "${EXCLUDE_DEVICE_MAPPING[@]}" ; do
            case "$current_device_basename" in
                ($pattern)
                    Log "$current_device_basename excluded from device mapping choices (matches '$pattern' in EXCLUDE_DEVICE_MAPPING)"
                    # Continue with next block device:
                    continue 2
                    ;;
            esac
        done
        preferred_target_device_name="$( get_device_name $current_device_path )"
        # Continue with next block device if the current one has no queue directory:
        if ! test -d $current_device_path/queue ; then
            Log "$preferred_target_device_name excluded from device mapping choices (has no queue directory)"
            continue
        fi
        # Continue with next block device if the current one is already used as target in the mapping file:
        if is_mapping_target "$preferred_target_device_name" ; then
            Log "$preferred_target_device_name excluded from device mapping choices (is already used as mapping target)"
            continue
        fi
        # Continue with next block device if the current one is designated as write-protected:
        if is_write_protected "$preferred_target_device_name"; then
            Log "$preferred_target_device_name excluded from device mapping choices (is designated as write-protected)"
            continue
        fi
        # Add the current device as possible choice for the user:
        possible_targets+=( "$preferred_target_device_name" )
    done
    # Continue with next original device when no appropriate current block device is found where to it could be mapped:
    if ! test "${possible_targets[*]}" ; then
        LogUserOutput "No device found where to $preferred_orig_device_name could be mapped so that it will not be recreated"
        continue
    fi
    # Automatically map when only one appropriate current block device is found where to it could be mapped.
    # At the end the mapping file is shown and the user can edit it if he does not like an automated mapping:
    if test "1" -eq "${#possible_targets[@]}" ; then
        add_mapping "$orig_device" "$possible_targets"
        LogPrint "Using $possible_targets (the only available of the disks) for recreating $orig_device"
        # Continue with next original device in the LAYOUT_FILE:
        continue
    fi
    # Show the appropriate current block devices and let the user choose:
    skip_choice="Do not map $preferred_orig_device_name"
    regular_choices=( "${possible_targets[@]}" "$skip_choice" )
    rear_shell_choice="Use Relax-and-Recover shell and return back to here"
    prompt="Choose an appropriate replacement for $preferred_orig_device_name"
    choice=""
    wilful_input=""
    # Generate a runtime-specific user_input_ID so that for each unmapped original device
    # a different user_input_ID is used for the UserInput call so that the user can specify
    # for each unmapped original device a different predefined user input.
    # Only uppercase letters and digits are used to ensure the user_input_ID is a valid bash variable name
    # (otherwise the UserInput call could become invalid which aborts 'rear recover' with a BugError) and
    # hopefully only uppercase letters and digits are sufficient to distinguish different devices:
    current_orig_device_basename_alnum_uppercase="$( basename "$preferred_orig_device_name" | tr -d -c '[:alnum:]' | tr '[:lower:]' '[:upper:]' )"
    test "$current_orig_device_basename_alnum_uppercase" || current_orig_device_basename_alnum_uppercase="DISK"
    user_input_ID="LAYOUT_MIGRATION_REPLACEMENT_$current_orig_device_basename_alnum_uppercase"
    until IsInArray "$choice" "${regular_choices[@]}" ; do
        # Default input is the first regular choice which is the first of the possible targets:
        choice="$( UserInput -I $user_input_ID -p "$prompt" -D 1 "${regular_choices[@]}" "$rear_shell_choice" )" && wilful_input="yes" || wilful_input="no"
        test "$rear_shell_choice" = "$choice" && rear_shell
    done
    # Continue with next original device when the user selected to not map it:
    if test "$skip_choice" = "$choice" ; then
        LogUserOutput "No mapping for $preferred_orig_device_name so that it will not be recreated"
        continue
    fi
    # Use what the user selected:
    add_mapping "$orig_device" "$choice"
    if is_true "$wilful_input" ; then
        LogUserOutput "Using $choice (chosen by user) for recreating $orig_device"
    else
        LogUserOutput "Using $choice (default choice) for recreating $orig_device"
    fi
done < <( grep -E "^disk |^multipath " "$LAYOUT_FILE" )

# Show the mappings to the user and let him confirm the mappings
# or let him edit the mapping file as he actually needs:
rear_workflow="rear $WORKFLOW"
rear_shell_history="$( echo -e "vi $MAPPING_FILE\nless $MAPPING_FILE" )"
unset choices
choices[0]="Confirm disk mapping and continue '$rear_workflow'"
choices[1]=""
choices[2]="Edit disk mapping ($MAPPING_FILE)"
choices[3]="Use Relax-and-Recover shell and return back to here"
choices[4]="Abort '$rear_workflow'"
prompt="Confirm or edit the disk mapping"
choice=""
wilful_input=""
# When USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm mapping' was actually meant:
is_true "$USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS" && USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS="${choices[0]}"
while true ; do
    LogUserOutput "$( output_valid_mappings )"
    LogUserOutput "$( output_not_recreated_devices )"
    is_completely_identical_layout_mapping && choices[1]="Confirm identical disk mapping and proceed without manual configuration" || choices[1]="n/a"
    choice="$( UserInput -I LAYOUT_MIGRATION_CONFIRM_MAPPINGS -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Continue recovery in migration mode:
            is_true "$wilful_input" && LogPrint "User confirmed disk mapping" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            if is_completely_identical_layout_mapping ; then
                # Confirm identical disk mapping and proceed without manual configuration:
                MIGRATION_MODE='false'
                # Move the mapping file away because some scripts
                # test for MAPPING_FILE to determine migration mode
                # TODO: clean up how for migration mode is tested
                # cf. https://github.com/rear/rear/issues/1857#issue-340210404
                mv $verbose -f $MAPPING_FILE $MAPPING_FILE.irrelevant_identical_mapping
                LogPrint "User confirmed identical disk mapping and proceeding without manual configuration"
                break
            else
                LogPrint "Not applicable (no identical disk mapping)"
            fi
            ;;
        (${choices[2]})
            # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            vi $MAPPING_FILE 0<&6 1>&7 2>&8
            ;;
        (${choices[3]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[4]})
            abort_recreate
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done

# Mark unmapped 'disk', 'multipath' and 'opaldisk' devices in the
# LAYOUT_FILE as done so that such devices will not be recreated
# except we are no longer in migration mode when the user confirmed an
# identical disk mapping and proceeding without manual configuration:
if is_true "$MIGRATION_MODE" ; then
    while read keyword device junk ; do
        is_mapping_source "$device" && continue
        if [[ "$keyword" == "opaldisk" ]]; then
            Log "TCG Opal 2-compliant self-encrypting disk $device will not be recreated"
            # Note: dependent devices might still be recreated if $device is mapped as a (non-encrypting) disk
            mark_as_done "opaldisk:$device"
        else
            LogUserOutput "Disk $device and all dependant devices will not be recreated"
            mark_as_done "$device"
            mark_tree_as_done "$device"
        fi
    done < <( grep -E "^disk |^multipath |^opaldisk " "$LAYOUT_FILE" )
fi

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f add_mapping
unset -f is_mapping_source
unset -f is_mapping_target
unset -f output_valid_mappings
unset -f output_not_recreated_devices

