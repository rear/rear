# Map source disks to target disks.

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

MAPPING_FILE="$VAR_DIR/layout/disk_mappings"
: > "$MAPPING_FILE"

generate_layout_dependencies

# Add a mapping from <source> to <target>
# Source/Target should be "like sda" "cciss/c1d0"
add_mapping() {
    echo "$1 $2" >> "$MAPPING_FILE"
}

# Return 0 if a mapping for <$1> exists.
mapping_exists() {
    if grep -q "^$1 " "$MAPPING_FILE" ; then
        return 0
    else
        return 1
    fi
}

# Return 0 if <$1> is used in a mapping.
reverse_mapping_exists() {
    if grep -q " $1$" "$MAPPING_FILE" ; then
        return 0
    else
        return 1
    fi
}

if [ -e "$CONFIG_DIR/mappings/disk_devices" ] ; then
    cp "$CONFIG_DIR/mappings/disk_devices" "$MAPPING_FILE"
fi

# Automap old disks.
while read disk dev size junk ; do
    if mapping_exists "$dev" ; then
        continue
    fi

    # First, try to find if the disk of the same name has the same size.
    if [ -e /sys/block/$(get_sysfs_name "$dev") ] ; then
        newsize=$(get_disk_size $(get_sysfs_name "$dev"))
        if [ "$size" -eq "$newsize" ] ; then
            add_mapping "$dev" "$dev"
            continue
        fi
    fi

    # Else, loop over all disks to find one of the same size.
    for path in /sys/block/* ; do
        if [ ! -r $path/size ] || [ ! -d $path/queue ] ; then
            continue
        fi
        newsize=$(get_disk_size ${path#/sys/block/})

        if [ "$size" -eq "$newsize" ] && ! reverse_mapping_exists "$(get_device_name $path)"; then
            add_mapping "$dev" "$(get_device_name $path)"
            break
        fi
    done
done < <(grep "^disk " "$LAYOUT_FILE")

# For every unmapped disk in the source system.
while read -u 3 disk dev size junk ; do
    if mapping_exists "$dev" ; then
        continue
    fi
    # Allow the user to select from the set of unmapped disks
    possible_targets=()
    for path in /sys/block/* ; do
        # Skipping removable devices
        if [ "$( < $path/removable)" = "1" ] ; then
            continue
        fi

        ### Skip if the name is in EXCLUDE_DEVICE_MAPPING
        skip=
        for name in "${EXCLUDE_DEVICE_MAPPING[@]}" ; do
            case "${path##*/}" in
                ($name)
                    skip=y
                    ;;
            esac
        done
        if [[ "$skip" ]] ; then
            continue
        fi

        if ! reverse_mapping_exists "$(get_device_name $path)" && [ -d $path/queue ] ; then
            possible_targets=("${possible_targets[@]}" "$(get_device_name $path)")
        fi
    done

    LogPrint "Original disk $(get_device_name $dev) does not exist in the target system. Please choose an appropriate replacement."
    select choice in "${possible_targets[@]}" "Do not map disk." ; do
        n=( $REPLY ) # trim blanks from reply
        let n-- # because bash arrays count from 0
        if [ "$n" = "${#possible_targets[@]}" ] || [ "$n" -lt 0 ] || [ "$n" -ge "${#possible_targets[@]}" ] ; then
            LogPrint "Disk $(get_device_name $dev) not automatically replaced."
        else
            LogPrint "Disk $choice chosen as replacement for $(get_device_name $dev)."
            add_mapping "$dev" "$choice"
        fi
        break
    done 2>&1 # to get the prompt, otherwise it would go to the logfile
done 3< <(grep "^disk " "$LAYOUT_FILE")

LogPrint "This is the disk mapping table:"
LogPrint "$(sed -e 's|^|    |' "$MAPPING_FILE")"

# Remove unmapped devices from disk layout
while read disk dev junk ; do
    if ! mapping_exists "$dev" ; then
        mark_as_done "$dev"
        mark_tree_as_done "$dev"
    fi
done < <(grep "^disk " "$LAYOUT_FILE")
