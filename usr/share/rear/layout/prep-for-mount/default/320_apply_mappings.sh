
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

# The rescue_config_file '/etc/rear/rescue.conf' may have contained a line like
# (cf. usr/share/rear/layout/save/GNU/Linux/230_filesystem_layout.sh):
#   BTRFS_SUBVOLUME_SLES_SETUP=( /dev/sda2 )
# that is now changed (e.g. because of a mapping from /dev/sda to /dev/sdb) to
#   BTRFS_SUBVOLUME_SLES_SETUP=( /dev/sdb2 )
# but /etc/rear/rescue.conf was already read by /etc/scripts/system-setup
# so that this changed variable must now be read again from /etc/rear/rescue.conf
# but we do not source the whole /etc/rear/rescue.conf again to be on the safe side
# perhaps some is not idempotent like "array+=( new elements )"
# or other variables in /etc/rear/rescue.conf may have been changed
# so we only re-read the BTRFS_SUBVOLUME_SLES_SETUP variable:
eval $( grep '^BTRFS_SUBVOLUME_SLES_SETUP=' "$rescue_config_file" )

