
# During "rear mkrescue/mkbackup/mkbackuponly/savelayout"
# save md5sum of config files in CHECK_CONFIG_FILES
# which is needed for comparison by "rear checklayout":

# During "rear checklayout" do not save new md5sum of files in CHECK_CONFIG_FILES because
# the old ones are needed for comparison in layout/compare/default/510_compare_files.sh
test "$WORKFLOW" = "checklayout" && return 0

local config_files=()
local obj
for obj in "${CHECK_CONFIG_FILES[@]}" ; do
    if test -d "$obj" ; then
        config_files+=( $( find "$obj" -type f ) )
    elif test -e "$obj" ; then
        config_files+=( "$obj" )
    fi
done

md5sum "${config_files[@]}" > $VAR_DIR/layout/config/files.md5sum

# During "rear mkrescue/mkbackup/mkbackuponly/savelayout"
# save which UUIDs in disklayout.conf appear in a config file in CHECK_CONFIG_FILES
# which is needed for comparison during "rear recover":

# Nothing to do when there are no UUIDs in disklayout.conf:
test -s $VAR_DIR/layout/config/disklayout.uuids || return 0

local uuid
local uuids_in_config_files=""
# Ignore duplicates (a UUID may appear more than once in disklayout.conf):
for uuid in $( sort -u $VAR_DIR/layout/config/disklayout.uuids ) ; do
    grep -q "$uuid" "${config_files[@]}" && uuids_in_config_files+=" $uuid"
done
# Remove duplicates (a UUID may appear in more than one config file) and
# have all as a single line of UUIDs separated by space (i.e. remove newlines):
uuids_in_config_files="$( for uuid in $uuids_in_config_files ; do echo "$uuid" ; done | sort -u | tr '\n' ' ' )"
# Store the UUIDs in disklayout.conf that appear in a config file in CHECK_CONFIG_FILES in the rescue configuration:
if test "$uuids_in_config_files" ; then
    { echo "# The following line was added by layout/save/default/600_snapshot_files.sh"
      echo "DISKLAYOUT_UUIDS_IN_CONFIG_FILES='$uuids_in_config_files'"
      echo ""
    } >> "$ROOTFS_DIR/etc/rear/rescue.conf"
fi
