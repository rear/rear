# Generate the $VAR_DIR/recovery/mountpoint_device file 
# This is needed by several backup mechanisms (DP, NBU, NETFS)

# TODO: rework other scripts to use LAYOUT_FILE directly

if [ -z "$USE_LAYOUT" ] ; then
    return 0
fi

while read fs device mountpoint junk ; do
    echo "$mountpoint $device"
done < <(grep ^fs $LAYOUT_FILE) > $VAR_DIR/recovery/mountpoint_device
