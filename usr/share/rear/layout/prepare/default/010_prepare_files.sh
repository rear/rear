# Create all files needed for layout restoration.

LAYOUT_FILE="$VAR_DIR/layout/disklayout.conf"
LAYOUT_DEPS="$VAR_DIR/layout/diskdeps.conf"
LAYOUT_TODO="$VAR_DIR/layout/disktodo.conf"
LAYOUT_CODE="$VAR_DIR/layout/diskrestore.sh"
LAYOUT_XFS_OPT_DIR="$VAR_DIR/layout/xfs"

FS_UUID_MAP="$VAR_DIR/layout/fs_uuid_mapping"
LUN_WWID_MAP="$VAR_DIR/layout/lun_wwid_mapping"

# Touchfiles for layout recreation.
LAYOUT_TOUCHDIR="$TMP_DIR/touch"
test -e $LAYOUT_TOUCHDIR && rm -rf $LAYOUT_TOUCHDIR
mkdir -p $LAYOUT_TOUCHDIR

test -e $LAYOUT_FILE && save_original_file $LAYOUT_FILE

if test -e $CONFIG_DIR/disklayout.conf ; then
    cp $CONFIG_DIR/disklayout.conf $LAYOUT_FILE
    # Only set MIGRATION_MODE if not already set (could be already specified by the user):
    if ! test "$MIGRATION_MODE" ; then
        MIGRATION_MODE='true'
        LogPrint "Switching to manual disk layout configuration ($CONFIG_DIR/disklayout.conf exists)"
    fi
    # For the LUN WWIDs migration code see finalize/GNU/Linux/250_migrate_lun_wwid.sh
    # TODO: Why are LUN WWIDs migrated only if also $CONFIG_DIR/disklayout.conf exists?
    # Why are LUN WWIDs not always migrated when only $CONFIG_DIR/lun_wwid_mapping.conf exists?
    # That part was added by
    # https://github.com/rear/rear/commit/e822ad69a8ce8dec6132741806008db9c6c3b429
    # but there is no comment that explains why LUN WWIDs migration happens
    # only if also $CONFIG_DIR/disklayout.conf exists.
    if test -e $CONFIG_DIR/lun_wwid_mapping.conf ; then
        cp $CONFIG_DIR/lun_wwid_mapping.conf $LUN_WWID_MAP
        LogPrint "Will migrate LUN WWIDs after backup restore ($CONFIG_DIR/lun_wwid_mapping.conf exists)"
    fi
fi

if ! test -e $LAYOUT_FILE ; then
    # TODO: This script layout/prepare/default/010_prepare_files.sh is only run during "rear recover"
    # and I <jsmeix@suse.de> wonder if "rear recover" can work at all without a disklayout.conf file?
    LogPrint "$LAYOUT_FILE file does not exist, creating empty file"
    : > $LAYOUT_FILE
fi

# Make sure old data is deleted:
test -e $FS_UUID_MAP && rm -f $FS_UUID_MAP
: > $LAYOUT_TODO
: > $LAYOUT_DEPS

