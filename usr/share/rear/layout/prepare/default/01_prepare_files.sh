# Create all files needed for layout restoration.

LAYOUT_FILE="$VAR_DIR/layout/disklayout.conf"
LAYOUT_DEPS="$VAR_DIR/layout/diskdeps.conf"
LAYOUT_TODO="$VAR_DIR/layout/disktodo.conf"
LAYOUT_CODE="$VAR_DIR/layout/diskrestore.sh"

if [ -e $LAYOUT_FILE ] ; then
    backup_file $LAYOUT_FILE
fi

if [ -e /etc/rear/disklayout.conf ] ; then
    cp /etc/rear/disklayout.conf $LAYOUT_FILE
    MIGRATION_MODE="true"
    LogPrint "/etc/rear/disklayout.conf exists, entering Migration mode."
fi

if [ ! -e $LAYOUT_FILE ] ; then
    Log "Disklayout file does not exist, creating empty file."
    : > $LAYOUT_FILE
fi

# $LAYOUT_DEPS is a list of:
# <item> <depends on>
: > $LAYOUT_DEPS

# $LAYOUT_TODO is a list of:
# [todo|done] <type> <item>
: > $LAYOUT_TODO

# $LAYOUT_CODE will contain the script to restore the environment.
cat > $LAYOUT_CODE <<EOF
#!/bin/bash

LogPrint "Start system layout restoration."

mkdir -p /mnt/local
lvm vgchange -a n > /dev/null

set -e
set -x

EOF
