# Exclude mountpoints from restore.
# This is based on the EXCLUDE_RESTORE and EXCLUDE_RECREATE variables.
# The output is written to RESTORE_EXCLUDE_FILE.

RESTORE_EXCLUDE_FILE="$TMP_DIR/restore-exclude-list.txt"
## FIXME: Use "$RESTORE_EXCLUDE_FILE" in other modules as well.

: >"$RESTORE_EXCLUDE_FILE"

local component

for component in "${EXCLUDE_RECREATE[@]}" ; do
    if ! IsInArray "$component" "${EXCLUDE_RESTORE[@]}" ; then
        EXCLUDE_RESTORE+=( "$component" )
    fi
done

local comp_type children child
local comp_types=( "btrfsmountedsubvol" "fs" )

for component in "${EXCLUDE_RESTORE[@]}" ; do
    for comp_type in "${comp_types[@]}"; do
        children=$(get_child_components "$component" "$comp_type" | sort -u)
        if [ -n "$children" ] ; then
            for child in $children ; do
                child=${child#$comp_type:}
                echo "${child#/}" >> "$RESTORE_EXCLUDE_FILE"
                echo "${child#/}/*" >> "$RESTORE_EXCLUDE_FILE"
            done
        fi
    done

    # exclude the component itself
    for comp_type in "${comp_types[@]}"; do
        component=${component#$comp_type:}
    done
    echo "${component#/}" >> "$RESTORE_EXCLUDE_FILE"
    echo "${component#/}/*" >> "$RESTORE_EXCLUDE_FILE"
done
