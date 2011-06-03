# find all physical non-removable devices

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return 0
fi

FindPhysicalDevices >$TMP_DIR/physical_devices
StopIfError "Abnormal error occured. Please check $LOGFILE for details."

# TODO: Exclude physical devices !!
