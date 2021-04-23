
# Backup all that is explicitly specified in BACKUP_PROG_INCLUDE:
for backup_include_item in "${BACKUP_PROG_INCLUDE[@]}" ; do
    test "$backup_include_item" && echo "$backup_include_item"
done > $TMP_DIR/backup-include.txt

# Implicitly also backup all local filesystems as defined in mountpoint_device
# except BACKUP_ONLY_INCLUDE or MANUAL_INCLUDE is set:
if ! is_true "$BACKUP_ONLY_INCLUDE" ; then
    if [ "${MANUAL_INCLUDE:-NO}" != "YES" ] ; then
        # Add the mountpoints that will be recovered to the backup include list
        # unless a mountpoint is excluded:
        while read mountpoint device junk ; do
            if ! IsInArray "$mountpoint" "${EXCLUDE_MOUNTPOINTS[@]}" ; then
                echo "$mountpoint"
            fi
        done <"$VAR_DIR/recovery/mountpoint_device" >> $TMP_DIR/backup-include.txt
    fi
fi

# Exclude all that is explicitly specified in BACKUP_PROG_EXCLUDE:
for backup_exclude_item in "${BACKUP_PROG_EXCLUDE[@]}" ; do
    test "$backup_exclude_item" && echo "$backup_exclude_item"
done > $TMP_DIR/backup-exclude.txt

# Implicitly also add excluded mountpoints to the backup exclude list
# except BACKUP_ONLY_EXCLUDE is set:
if ! is_true "$BACKUP_ONLY_EXCLUDE" ; then
    for excluded_mountpoint in "${EXCLUDE_MOUNTPOINTS[@]}" ; do
        test "$excluded_mountpoint" && echo "$excluded_mountpoint/"
    done >> $TMP_DIR/backup-exclude.txt
fi

