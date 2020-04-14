# Exclude mountpoints from restore.
# This is based on the EXCLUDE_RESTORE and EXCLUDE_RECREATE variables.
# The output is written to RESTORE_EXCLUDE_FILE.

RESTORE_EXCLUDE_FILE="$TMP_DIR/restore-exclude-list.txt"
## FIXME: Use "$RESTORE_EXCLUDE_FILE" in other modules as well.

: >"$RESTORE_EXCLUDE_FILE"

for component in "${EXCLUDE_RECREATE[@]}" ; do
    if ! IsInArray "$component" "${EXCLUDE_RESTORE[@]}" ; then
        EXCLUDE_RESTORE+=( "$component" )
    fi
done

for component in "${EXCLUDE_RESTORE[@]}" ; do
    fs_children=$(get_child_components "$component" "fs" | sort -u)
    if [ -n "$fs_children" ] ; then
        for child in $fs_children ; do
            child=${child#fs:}
            echo "${child#/}" >> "$RESTORE_EXCLUDE_FILE"
            echo "${child#/}/*" >> "$RESTORE_EXCLUDE_FILE"
        done
    else
        # if there are no fs deps, assume it is a wildcard path
        component=${component#fs:}
        echo "${component#/}" >> "$RESTORE_EXCLUDE_FILE"
        echo "${component#/}/*" >> "$RESTORE_EXCLUDE_FILE"
    fi
done
