# /usr/share/rear/backup/BORG/default/410_update_exclude_files.sh

if [[ -f "$BORGBACKUP_EXCLUDE_FILE" ]] ; then
    cat /dev/null > "$TMP_DIR/backup-excludes.txt"
    while read -r backup_exclude_item ; do
        test "$backup_exclude_item" || continue
        echo "$backup_exclude_item" >> "$TMP_DIR/backup-excludes.txt"
    done <<< $(cat "$BORGBACKUP_EXCLUDE_FILE" | grep -v ^\#)
fi

# We not delete the excludes created by 400_create_include_exclude_files.sh
cat "$TMP_DIR/backup-exclude.txt" >> "$TMP_DIR/backup-excludes.txt"

# backup-exclude.txt is backup-excludes.txt without duplicates but keeps the ordering:
unique_unsorted "$TMP_DIR/backup-excludes.txt" > "$TMP_DIR/backup-exclude.txt"
