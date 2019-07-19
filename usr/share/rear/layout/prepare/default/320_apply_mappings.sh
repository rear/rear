
# In migration mode apply the disk layout mappings to disklayout.conf
# and related files that are also used to migrate the disk layout
# cf. https://github.com/rear/rear/issues/2181

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

local original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
local rescue_config_file="/etc/rear/rescue.conf"
local applied_mappings_to_all_files="yes"
local file_to_migrate=""

for file_to_migrate in "$LAYOUT_FILE" "$original_disk_space_usage_file" "$rescue_config_file" ; do
    # Skip if file_to_migrate does not exist or is empty (e.g. original_disk_space_usage_file may not exist):
    test -s "$file_to_migrate" || continue
    if apply_layout_mappings "$file_to_migrate" ; then
        DebugPrint "Applied disk layout mappings to $file_to_migrate"
    else
        LogPrintError "Failed to apply disk layout mappings to $file_to_migrate"
        applied_mappings_to_all_files="no"
    fi
done

is_true $applied_mappings_to_all_files || Error "Failed to apply disk layout mappings"

