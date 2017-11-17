# 410_verify_nsr_paths.sh
#
# Execute in case NSR_CLIENT_MODE is NOT enabled (default)
#
if ! is_true "$NSR_CLIENT_MODE"; then
    [[ ! -f $VAR_DIR/recovery/nsr_paths ]] && Error "Missing save sets filesystems to recover from EMC NetWorker"

    LogPrint "We will recover the following file systems from EMC NetWorker: $( cat $VAR_DIR/recovery/nsr_paths )"
fi
