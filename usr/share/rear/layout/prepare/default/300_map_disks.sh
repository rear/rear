
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
# i.e. if $1 is used as source in the mapping file
# (grep returns 0 if found and 1 or 2 otherwise):
function is_mapping_source () {
    grep -q "^$1 " "$MAPPING_FILE"
}

# Return 0 if $1 is used as a target in a mapping
# (grep returns 0 if found and 1 or 2 otherwise):
function is_mapping_target () {
    grep -q " $1$" "$MAPPING_FILE"
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
    is_mapping_source "$orig_device" && continue
    # First, try to find if there is a current disk with same name and same size as the original:
    sysfs_device_name="$( get_sysfs_name "$orig_device" )"
    current_device="/sys/block/$sysfs_device_name"
    if test -e $current_device ; then
        current_size=$( get_disk_size $sysfs_device_name )
        # The current_device (e.g. /sys/block/sda) is not a block device so that
        # its matching actual block device (e.g. /dev/sda) must be determined:
        preferred_target_device_name="$( get_device_name $current_device )"
        # Continue with next one if the current one is already used as target in the mapping file:
        is_mapping_target "$preferred_target_device_name" && continue
        # Use the current one if it is of same size as the old one:
        if test "$orig_size" -eq "$current_size" ; then
            # Ensure the determined target device is really a block device:
            if test -b "$preferred_target_device_name" ; then
                add_mapping "$orig_device" "$preferred_target_device_name"
                LogPrint "Using $preferred_target_device_name (same name and same size) for recreating $orig_device"
                # Continue with next original device in the LAYOUT_FILE:
                continue
            fi
        fi
    fi
    # Else, loop over all current block devices to find one of the same size as the original:
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
        # Continue with next one if the current one is already used as target in the mapping file:
        is_mapping_target "$preferred_target_device_name" && continue
        # Use the current one if it is of same size as the old one:
        if test "$orig_size" -eq "$current_size" ; then
            # Ensure the determined target device is really a block device:
            if test -b "$preferred_target_device_name" ; then
                add_mapping "$orig_device" "$preferred_target_device_name"
                LogPrint "Using $preferred_target_device_name (same size) for recreating $orig_device"
                # Break looping over all current block devices to find one
                # and continue with next original device in the LAYOUT_FILE:
                break
            fi
        fi
    done
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
        # Do not include removable devices in the choices for the user:
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
        # Add the current device as possible choice for the user:
        possible_targets=( "${possible_targets[@]}" "$preferred_target_device_name" )
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
        LogPrint "Using $possible_targets (the only appropriate) for recreating $orig_device"
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
choices[1]="Edit disk mapping ($MAPPING_FILE)"
choices[2]="Use Relax-and-Recover shell and return back to here"
choices[3]="Abort '$rear_workflow'"
prompt="Confirm or edit the disk mapping"
choice=""
wilful_input=""
# When USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm mapping' was actually meant:
is_true "$USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS" && USER_INPUT_LAYOUT_MIGRATION_CONFIRM_MAPPINGS="${choices[0]}"
while true ; do
    LogUserOutput 'Current disk mapping table (source -> target):'
    LogUserOutput "$( sed -e 's|^|    |' "$MAPPING_FILE" )"
    choice="$( UserInput -I LAYOUT_MIGRATION_CONFIRM_MAPPINGS -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Continue recovery:
            is_true "$wilful_input" && LogPrint "User confirmed disk mapping" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            vi $MAPPING_FILE 0<&6 1>&7 2>&8
            ;;
        (${choices[2]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[3]})
            abort_recreate
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done

# Mark unmapped 'disk' devices and 'multipath' devices in the LAYOUT_FILE as done
# so that unmapped 'disk' and 'multipath' devices will not be recreated:
while read keyword device junk ; do
    if ! is_mapping_source "$device" ; then
        LogUserOutput "Disk $device and all dependant devices will not be recreated"
        mark_as_done "$device"
        mark_tree_as_done "$device"
    fi
done < <( grep -E "^disk |^multipath " "$LAYOUT_FILE" )

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f add_mapping
unset -f is_mapping_source
unset -f is_mapping_target

