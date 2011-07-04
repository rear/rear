# Exclude mountpoints from restore
# This is based on the EXCLUDE_RESTORE and EXCLUDE_RECREATE variables
# The output is written to

: > $TMP_DIR/restore-exclude-list.txt

for component in "${EXCLUDE_RECREATE[@]}" ; do
    if ! IsInArray "$component" "${EXCLUDE_RESTORE}" ; then
        EXCLUDE_RESTORE=( "${EXCLUDE_RESTORE[@]}" "$component" )
    fi
done

for component in "${EXCLUDE_RESTORE[@]}" ; do
    fs_children=$(get_child_components "$component" "fs" | sort -u)
    if [ -n "$fs_children" ] ; then
        for child in $fs_children ; do
            child=${child#fs:}
            echo "${child#/}" >> $TMP_DIR/restore-exclude-list.txt
            echo "${child#/}/*" >> $TMP_DIR/restore-exclude-list.txt
        done
    else
        # if there are no fs deps, assume it is a wildcard path
        component=${component#fs:}
        echo "${component#/}" >> $TMP_DIR/restore-exclude-list.txt
        echo "${component#/}/*" >> $TMP_DIR/restore-exclude-list.txt
    fi
done

