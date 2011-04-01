# Automatically exclude disks that do not have filesystems mounted.
if [ -n "$AUTOEXCLUDE_DISKS" ] ; then
    used_disks=()

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
            LogPrint "Disk $name is not used by any mounted filesystem. Excluding."
            mark_as_done "$name"
            mark_tree_as_done "$name"
        fi
    done < <(grep ^disk $LAYOUT_FILE)

fi
