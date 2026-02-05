# Create the layout file

LogPrint "Creating disk layout"

Log "Creating layout directories (when not existing)"
mkdir -p $v $VAR_DIR/layout
mkdir -p $v $VAR_DIR/recovery
mkdir -p $v $VAR_DIR/layout/config

# We need directory for XFS options only if XFS is in use:
if test "$( mount -t xfs )" ; then
    LAYOUT_XFS_OPT_DIR="$VAR_DIR/layout/xfs"
    rm -rf $LAYOUT_XFS_OPT_DIR
    mkdir -p $v $LAYOUT_XFS_OPT_DIR
fi

# Use exiting DISKLAYOUT_FILE value or use the default:
test "$DISKLAYOUT_FILE" || DISKLAYOUT_FILE=$VAR_DIR/layout/disklayout.conf

# Inform the user (he may have specified his DISKLAYOUT_FILE value, see above):
test -e "$DISKLAYOUT_FILE" && LogPrint "Overwriting existing disk layout file $DISKLAYOUT_FILE"

# Initialize disklayout.conf:
echo "Disk layout dated $START_DATE_TIME_NUMBER (YYYYmmddHHMMSS)" >$DISKLAYOUT_FILE
# Have the actual storage layout as header comment in disklayout.conf
# so that it is easier to make sense of the values in the subsequent entries.
# First try the command ('MOUNTPOINTS' with plural 'S' shows all mounted btrfs subvolumes)
#   lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS,UUID,PARTUUID,WWN
# then try the command (e.g. on SLES12 only 'MOUNTPOINT' works which shows a random one of the mounted btrfs subvolumes)
#   lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID,PARTUUID,WWN
# but on older systems (like SLES11) that do not support all that lsblk things
# cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
# try the simpler command
#   lsblk -io NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID,PARTUUID
# try the command without PARTUUID (e.g., RHEL 6 is not aware of this)
#   lsblk -io NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID
# and as fallback try 'lsblk -i' and finally try plain 'lsblk'.
# When there is no 'lsblk' command there is no output (bad luck, no harm):
{ lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS,UUID,PARTUUID,WWN || \
  lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID,PARTUUID,WWN || \
  lsblk -io NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID,PARTUUID || \
  lsblk -io NAME,KNAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,UUID || \
  lsblk -i || lsblk ; } >>"$DISKLAYOUT_FILE"
# Make all lines in disklayout.conf up to now as header comments:
sed -i -e 's/^/# /' $DISKLAYOUT_FILE

LAYOUT_FILE="$DISKLAYOUT_FILE"
LAYOUT_DEPS="$VAR_DIR/layout/diskdeps.conf"
LAYOUT_TODO="$VAR_DIR/layout/disktodo.conf"

# $LAYOUT_DEPS is a list of:
# <item> <depends on>
: > $LAYOUT_DEPS

# $LAYOUT_TODO is a list of:
# [todo|done] <type> <item>
: > $LAYOUT_TODO

