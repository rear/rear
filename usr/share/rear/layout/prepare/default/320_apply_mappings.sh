# Apply the mapping in the layout file.

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

apply_layout_mappings $LAYOUT_FILE
