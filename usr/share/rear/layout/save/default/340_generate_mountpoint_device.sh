# Generate the $VAR_DIR/recovery/mountpoint_device file
# This is needed by several backup mechanisms (DP, NBU, NETFS)

# TODO: rework other scripts to use LAYOUT_FILE directly

# Find all mountpoints excluded using EXCLUDE_BACKUP
# EXCLUDE_RECREATE is handled automatically (commented out in LAYOUT_FILE)
excluded_mountpoints=()
while read fs device mountpoint junk ; do
    if IsInArray "fs:$mountpoint" "${EXCLUDE_BACKUP[@]}" ; then
        excluded_mountpoints+=( $mountpoint )
    fi
    for component in $(get_parent_components "fs:$mountpoint" | sort -u) ; do
        if IsInArray "$component" "${EXCLUDE_BACKUP[@]}" ; then
            excluded_mountpoints+=( $mountpoint )
        fi
    done
done < <(grep ^fs $LAYOUT_FILE)

# Generate the list of mountpoints and devices to exclude from backup
while read fs device mountpoint junk ; do
    if IsInArray "$mountpoint" "${excluded_mountpoints[@]}" ; then
        continue
    fi
    echo "$mountpoint $device"
done < <(grep '^fs' $LAYOUT_FILE) > $VAR_DIR/recovery/mountpoint_device
