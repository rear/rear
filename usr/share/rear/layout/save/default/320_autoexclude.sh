# Automatically exclude multipath devices
if [[ "$AUTOEXCLUDE_MULTIPATH" =~ ^[yY1] ]] ; then
    while read multipath device devices junk ; do
        Log "Automatically excluding multipath device $device."
        mark_as_done "$device"
        mark_tree_as_done "$device"
    done < <(grep ^multipath $LAYOUT_FILE)
fi

### Automatically exclude filesystems under a certain path
### This should cover automatically attached USB devices.
if [[ "$AUTOEXCLUDE_PATH" ]] ; then
    for exclude in "${AUTOEXCLUDE_PATH[@]}" ; do
        while read fs device mountpoint junk ; do
            if [[ "${mountpoint#${exclude%/}/}" != "$mountpoint" ]] ; then
                Log "Automatically excluding filesystem $mountpoint."
                mark_as_done "fs:$mountpoint"
                mark_tree_as_done "fs:$mountpoint"
                ### by excluding the filesystem, the device will be excluded by the
                ### automatic exclusion of disks without mounted filesystems.
            fi
        done < <(grep ^fs $LAYOUT_FILE)
    done
fi

# Automatically exclude filesystems mounted from USB devices found in OUTPUT_URL or BACKUP_URL
if [[ "$AUTOEXCLUDE_USB_PATH" ]] ; then
    for exclude in "${AUTOEXCLUDE_USB_PATH[@]}" ; do
        while read fs device mountpoint junk ; do
            if [[ "$exclude" = "$mountpoint" ]] ; then
                Log "Automatically excluding filesystem $mountpoint (USB device $device)."
                mark_as_done "fs:$mountpoint"
                mark_tree_as_done "fs:$mountpoint"
                ### by excluding the filesystem, the device will also be excluded
            fi
        done < <(grep ^fs $LAYOUT_FILE)
    done
fi

# Automatically exclude disks that do not have filesystems mounted.
if [[ "$AUTOEXCLUDE_DISKS" =~ ^[yY1] ]] ; then
    used_disks=()
    # List disks used by swap devices
    while read swap device uuid label junk ; do

        if grep -q "^done swap:$device " $LAYOUT_TODO ; then
            continue
        fi

        disks=$(find_disk swap:$device)
        for disk in $disks ; do
            if ! IsInArray "$disk" "${used_disks[@]}" ; then
                used_disks=( "${used_disks[@]}" "$disk" )
            fi
        done

    done < <(grep ^swap $LAYOUT_FILE)

    # List disks used by mountpoints
    while read fs device mountpoint junk ; do

        if IsInArray "$mountpoint" "${EXCLUDE_MOUNTPOINTS[@]}" ; then
            # Excluded mountpoints can lead to disks that aren't needed
            continue
        fi

        # is a filesystem is already marked as done, it's not used
        if grep -q "^done fs:$mountpoint " $LAYOUT_TODO ; then
            continue
        fi

        disks=$(find_disk fs:$mountpoint)
        for disk in $disks ; do
            if ! IsInArray "$disk" "${used_disks[@]}" ; then
                used_disks=( "${used_disks[@]}" "$disk" )
            fi
        done
    done < <(grep ^fs $LAYOUT_FILE)

    # Find out which disks were not in the list and remove them.
    while read disk name junk ; do
        if ! IsInArray "$name" "${used_disks[@]}" ; then
            Log "Disk $name is not used by any mounted filesystem. Excluding."
            mark_as_done "$name"
            # If this was a self-encrypting disk, remove its entry, too.
            mark_as_done "opaldisk:$name"
            mark_tree_as_done "$name"
        fi
    done < <(grep ^disk $LAYOUT_FILE)

fi

### Prevent partitioning of the underlying devices on multipath
while read multipath device dm_size slaves junk ; do
    local -a devices=()

    OIFS=$IFS
    IFS=","
    for slave in $slaves ; do
        devices=( "${devices[@]}" "$slave" )
    done
    IFS=$OIFS

    for slave in "${devices[@]}" ; do
        Log "Excluding multipath slave $slave."
        mark_as_done "$slave"
        ### the slave can have partitions, also exclude them
        while read child parent junk ; do
            if [[ "$child" != "$device" ]] ; then
                mark_as_done "$child"
            fi
        done < <(grep "$slave$" $LAYOUT_DEPS)
    done
done < <(grep ^multipath $LAYOUT_FILE)

### Automatically exclude autofs devices
if [[ -n "$AUTOEXCLUDE_AUTOFS" ]] ; then
    while read name mountpoint junk ; do
        BACKUP_PROG_EXCLUDE=( "${BACKUP_PROG_EXCLUDE[@]}" "$mountpoint" )
    done < <(grep " autofs " /proc/mounts)
fi
