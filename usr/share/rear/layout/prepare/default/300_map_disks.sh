
# Map source disks to target disks.

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

generate_layout_dependencies

mapping_file_basename="disk_mappings"

MAPPING_FILE="$VAR_DIR/layout/$mapping_file_basename"
: > "$MAPPING_FILE"

# Add a disk mapping from source $1 to target $2.
# Source and target should be like "sda" "cciss/c1d0".
add_mapping() {
    echo "$1 $2" >> "$MAPPING_FILE"
}

# Return 0 if a mapping for $1 exists
# i.e. if $1 is used as source in the mapping file
# (grep returns 0 if found and 1 or 2 otherwise):
is_mapping_source() {
    grep -q "^$1 " "$MAPPING_FILE"
}

# Return 0 if $1 is used as a target in a mapping
# (grep returns 0 if found and 1 or 2 otherwise):
is_mapping_target() {
    grep -q " $1$" "$MAPPING_FILE"
}

# If etc/rear/mappings/disk_mappings or etc/rear/mappings/disk_devices exists
# use that as mapping file where etc/rear/mappings/disk_mappings is preferred
# and etc/rear/mappings/disk_devices is only kept for backward compatibility:
for user_provided_mapping_file in disk_devices $mapping_file_basename ; do
    test -f "$user_provided_mapping_file" && cp "$user_provided_mapping_file" "$MAPPING_FILE"
done

# Automap old 'disk' devices and old 'multipath' devices in the LAYOUT_FILE
# to current block devices in the currently running recovery system:
while read keyword old_device old_size junk ; do
    # Continue with next old device when it is already used as source in the mapping file:
    is_mapping_source "$old_device" && continue
    # First, try to find if there is a current disk with same name and same size as the old one:
    sysfs_device_name="$( get_sysfs_name "$old_device" )"
    current_device="/sys/block/$sysfs_device_name"
    if test -e $current_device ; then
        current_size=$( get_disk_size $sysfs_device_name )
        if test "$old_size" -eq "$current_size" ; then
            add_mapping "$old_device" "$current_device"
            # Continue with next old device in the LAYOUT_FILE:
            continue
        fi
    fi
    # Else, loop over all current block devices to find one of the same size:
    for current_device_path in /sys/block/* ; do
        # Continue with next block device if the current one has no queue directory:
        test -d $current_device_path/queue || continue
        # Continue with next block device if no size can be read for the current one:
        test -r $current_device_path/size || continue
        current_disk_name="${current_device_path#/sys/block/}"
        current_size=$( get_disk_size $current_disk_name )
        preferred_target_device_name="$( get_device_name $current_device_path )"
        # Continue with next one if the current one is already used as target in the mapping file:
        is_mapping_target "$preferred_target_device_name" && continue
        # Use the current one if it is of same size as the old one:
        if test "$old_size" -eq "$current_size" ; then
            LogUserOutput "Disk $preferred_target_device_name will be used as replacement for $old_device"
            add_mapping "$old_device" "$preferred_target_device_name"
            # Continue with next old device in the LAYOUT_FILE:
            break
        fi
    done
done < <(grep -E "^disk |^multipath " "$LAYOUT_FILE")

# For every unmapped old 'disk' devices and old 'multipath' devices in the LAYOUT_FILE
# let the user choose from the still unmapped disks in the currently running recovery system:
while read -u 3 keyword old_device old_size junk ; do
    # Continue with next old device when it is already used as source in the mapping file
    # i.e. when it is already mapped to one in the currently running recovery system:
    is_mapping_source "$old_device" && continue
    # Inform the user about the unmapped old device:
    preferred_old_device_name="$( get_device_name $old_device )"
    LogUserOutput "Original disk $preferred_old_device_name does not exist in the target system."
    # Build the set of still unmapped disks wherefrom the user can choose:
    possible_targets=()
    # Loop over all current block devices to find appropriate ones wherefrom the user can choose:
    for current_device_path in /sys/block/* ; do
        # Do not include removable devices in the choices for the user:
        test "$( < $current_device_path/removable )" = "1" && continue
        # Do not include devices in EXCLUDE_DEVICE_MAPPING in the choices for the user:
        current_device_basename="${current_device_path##*/}"
        # One cannot use IsInArray here because EXCLUDE_DEVICE_MAPPING contains patterns
        # (e.g. "loop*" and "ram*" see default.conf) so that 'case' pattern matching is used:
        for pattern in "${EXCLUDE_DEVICE_MAPPING[@]}" ; do
            case "$current_device_basename" in
                ($pattern)
                    # Continue with next block device:
                    continue 2
                    ;;
            esac
        done
        preferred_target_device_name="$( get_device_name $current_device_path )"
        # Continue with next block device if the current one is already used as target in the mapping file:
        is_mapping_target "$preferred_target_device_name" && continue
        # If the current device has a queue directory add the current device as possible choice for the user:
        test -d $current_device_path/queue && possible_targets=( "${possible_targets[@]}" "$preferred_target_device_name" )
    done
    # Continue with next old device when no appropriate current block device is found whereto map it.
    test "${possible_targets[*]}" || continue
    # Show the appropriate current block devices and let the user choose:
    skip_choice="Do not map $preferred_old_device_name"
    choices=( "${possible_targets[@]}" "$skip_choice" )
    prompt="Choose an appropriate replacement for $preferred_old_device_name"
    until IsInArray "$choice" "${choices[@]}" ; do
        choice="$( UserInput -p "$prompt" -D 0 "${choices[@]}" )"
    done
    # Continue with next old device when the user selected to not map it:
    if test "$skip_choice" = "$choice" ; then
        LogUserOutput "No mapping for $preferred_old_device_name so that it will not be recreated"
        continue
    fi
    # Use what the user selected:
    LogUserOutput "Disk $choice will be used as replacement for $old_device"
    add_mapping "$old_device" "$choice"
done 3< <(grep -E "^disk |^multipath " "$LAYOUT_FILE")

LogUserOutput "This is the disk mapping table:"
LogUserOutput "    source-disk target-disk"
LogUserOutput "$( sed -e 's|^|    |' "$MAPPING_FILE" )"

# Mark unmapped 'disk' devices and 'multipath' devices in the LAYOUT_FILE as done
# so that unmapped 'disk' and 'multipath' devices will not be recreated:
while read keyword device junk ; do
    if ! is_mapping_source "$device" ; then
        LogUserOutput "Disk $device and all dependant devices will not be recreated"
        mark_as_done "$device"
        mark_tree_as_done "$device"
    fi
done < <(grep -E "^disk |^multipath " "$LAYOUT_FILE")

