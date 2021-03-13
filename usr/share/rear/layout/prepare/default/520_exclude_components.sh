# Exclude components.

for component in "${EXCLUDE_RECREATE[@]}" ; do
    Log "Excluding $component from recreate stage."
    mark_as_done "$component"
    mark_tree_as_done "$component"
done

### Make sure we have all dependencies for multipath devices in place.
while read multipath device dm_size label slaves junk ; do
    local -a devices=()

    OIFS=$IFS
    IFS=","
    for slave in $slaves ; do
        devices+=( "$slave" )
    done
    IFS=$OIFS

    for slave in "${devices[@]}" ; do
        add_component "$slave"
        mark_as_done "$slave"
    done
done < <(grep ^multipath "$LAYOUT_FILE")
