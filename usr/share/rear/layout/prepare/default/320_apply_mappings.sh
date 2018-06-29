# Apply the mapping in the layout file.

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

apply_layout_mappings "$LAYOUT_FILE" || Error "Failed to apply disklayout mappings to $LAYOUT_FILE"

