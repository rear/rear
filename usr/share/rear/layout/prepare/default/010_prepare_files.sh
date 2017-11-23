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
if [ -e $LAYOUT_TOUCHDIR ] ; then
    rm -rf $LAYOUT_TOUCHDIR
fi
mkdir -p $LAYOUT_TOUCHDIR

if [ -e $LAYOUT_FILE ] ; then
    backup_file $LAYOUT_FILE
fi

if [ -e $CONFIG_DIR/disklayout.conf ] ; then
    cp $CONFIG_DIR/disklayout.conf $LAYOUT_FILE
    # Only set MIGRATION_MODE if not already set (could be already specified by the user):
    if ! test "$MIGRATION_MODE" ; then
        MIGRATION_MODE='true'
        LogPrint "Switching to manual disk layout configuration ($CONFIG_DIR/disklayout.conf exists)"
    fi

    if [ -e $CONFIG_DIR/lun_wwid_mapping.conf ] ; then
        cp $CONFIG_DIR/lun_wwid_mapping.conf $LUN_WWID_MAP
        LogPrint "$CONFIG_DIR/lun_wwid_mapping.conf exists, creating lun_wwid_mapping"
    fi
fi

if [ ! -e $LAYOUT_FILE ] ; then
    Log "Disklayout file does not exist, creating empty file."
    : > $LAYOUT_FILE
fi

if [ -e $FS_UUID_MAP ] ; then
    rm -f $FS_UUID_MAP  # Make sure old data is deleted.
fi

: > $LAYOUT_TODO
: > $LAYOUT_DEPS
