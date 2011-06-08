# Include/Exclude components

# Available configuration options:
# EXCLUDE_MOUNTPOINTS
# EXCLUDE_MD
# EXCLUDE_VG
# INCLUDE_VG

# Uses the LAYOUT_TODO and LAYOUT_DEPS files to mark excluded files as done.

# If a filesystem is excluded (for backup) we still may need to perform an
# mkfs on the filesystem as it may be referenced in fstab and mounted
# automatically, or is needed for a separate restore.
#
# If you somehow need this functionality, it's advised to exclude the
# device or volume group
#for mountpoint in "${EXCLUDE_MOUNTPOINTS[@]}" ; do
#    LogPrint "Excluding mountpoint $mountpoint."
#    mark_as_done "fs:$mountpoint"
#    mark_tree_as_done "fs:$mountpoint"
#done

for md in "${EXCLUDE_MD[@]}" ; do
    LogPrint "Excluding RAID $md."
    mark_as_done "/dev/$md"
    mark_tree_as_done "/dev/$md"
done

for vg in "${EXCLUDE_VG[@]}" ; do
    LogPrint "Excluding Volume Group $vg."
    mark_as_done "/dev/$vg"
    mark_tree_as_done "/dev/$vg"
done

if [ ${#ONLY_INCLUDE_VG[@]} -gt 0 ] ; then
    while read lvmgrp name junk ; do
        if ! IsInArray "${name#/dev/}" "${ONLY_INCLUDE_VG[@]}" ; then
            LogPrint "Excluding Volume Group ${name#/dev/}"
            mark_as_done "$name"
            mark_tree_as_done "$name"
        fi
    done < <(grep ^lvmgrp $LAYOUT_FILE)
fi

for component in "${EXCLUDE_COMPONENTS[@]}" ; do
    LogPrint "Excluding component $component."
    mark_as_done "$component"
    mark_tree_as_done "$component"
done

for component in "${EXCLUDE_RECREATE[@]}" ; do
    LogPrint "Excluding component $component"
    mark_as_done "$component"
    mark_tree_as_done "$component"
done
