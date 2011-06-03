# find all physical non-removable devices

FindPhysicalDevices >$VAR_DIR/recovery/physical_devices
StopIfError "Abnormal error occured. Please check $LOGFILE for details."

# TODO: Exclude physical devices !!
