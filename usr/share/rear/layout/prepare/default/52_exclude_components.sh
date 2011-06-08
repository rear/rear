# Exclude components

for component in "${EXCLUDE_RECREATE[@]}" ; do
    Log "Excluding $component from recreate stage."
    mark_as_done "$component"
    mark_tree_as_done "$component"
done
