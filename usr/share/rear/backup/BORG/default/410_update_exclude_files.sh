# backup/BORG/default/410_update_exclude_files.sh

# The BORGBACKUP_EXCLUDE_FILE is a file that could also be used by 'borg'
# outside of ReaR. ReaR should respect the end-user exclude rules, therefore,
# we also add these items to the $TMP_DIR/backup-exclude.txt file.
if [[ -f "$BORGBACKUP_EXCLUDE_FILE" ]] ; then
    cat /dev/null > "$TMP_DIR/backup-excludes.txt"
    while read -r backup_exclude_item ; do
        test "$backup_exclude_item" || continue
        echo "$backup_exclude_item" >> "$TMP_DIR/backup-excludes.txt"
    done <<< $(grep -v ^\# "$BORGBACKUP_EXCLUDE_FILE")
fi

# We will append the excludes created by 400_create_include_exclude_files.sh
cat "$TMP_DIR/backup-exclude.txt" >> "$TMP_DIR/backup-excludes.txt"

# backup-exclude.txt is backup-excludes.txt without duplicates but keeps the ordering:
unique_unsorted "$TMP_DIR/backup-excludes.txt" > "$TMP_DIR/backup-exclude.txt"
