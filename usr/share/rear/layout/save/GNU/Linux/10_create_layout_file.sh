# Create the layout file

LogPrint "Creating disk layout"
Log "Preparing layout directory."
mkdir -p $v $VAR_DIR/layout >&2
mkdir -p $v $VAR_DIR/recovery >&2
mkdir -p $v $VAR_DIR/layout/config >&2

DISKLAYOUT_FILE=${DISKLAYOUT_FILE:-$VAR_DIR/layout/disklayout.conf}

if [ -e "$DISKLAYOUT_FILE" ] ; then
    Log "Removing old layout file."
fi
: > $DISKLAYOUT_FILE

LAYOUT_FILE="$DISKLAYOUT_FILE"
LAYOUT_DEPS="$VAR_DIR/layout/diskdeps.conf"
LAYOUT_TODO="$VAR_DIR/layout/disktodo.conf"

# $LAYOUT_DEPS is a list of:
# <item> <depends on>
: > $LAYOUT_DEPS

# $LAYOUT_TODO is a list of:
# [todo|done] <type> <item>
: > $LAYOUT_TODO
