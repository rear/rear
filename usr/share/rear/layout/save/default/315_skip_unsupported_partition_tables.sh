# Mark components on disks with unsupported partition tables as done.
# Disks are recorded in $VAR_DIR/layout/skipped_unsupported_disks by
# layout/save/GNU/Linux/200_partition_layout.sh when SKIP_UNSUPPORTED_PARTITION_TABLES is enabled.
# Filesystems on those disks may have been saved by 230_filesystem_layout.sh before dependencies exist;
# mark them done here so 330_remove_exclusions.sh comments them out in disklayout.conf.
test -s "$VAR_DIR/layout/skipped_unsupported_disks" || return 0
while read skipped_disk junk ; do
    test "$skipped_disk" || continue
    LogPrint "Marking skipped unsupported partition table disk $skipped_disk as done"
    mark_as_done "$skipped_disk"
    mark_tree_as_done "$skipped_disk"
    # Mark filesystems on partitions of this disk as done:
    while read fs device mountpoint fstype junk ; do
        case "$device" in
            (${skipped_disk}|${skipped_disk}*)
                LogPrint "Marking filesystem $mountpoint on skipped disk $skipped_disk as done"
                mark_as_done "fs:$mountpoint"
                mark_tree_as_done "fs:$mountpoint"
                ;;
        esac
    done < <(grep '^fs ' "$LAYOUT_FILE")
    # Mark swap on this disk as done:
    while read swap device uuid label junk ; do
        case "$device" in
            (${skipped_disk}|${skipped_disk}*)
                LogPrint "Marking swap on skipped disk $skipped_disk as done"
                mark_as_done "swap:$device"
                mark_tree_as_done "swap:$device"
                ;;
        esac
    done < <(grep '^swap ' "$LAYOUT_FILE")
done < "$VAR_DIR/layout/skipped_unsupported_disks"
