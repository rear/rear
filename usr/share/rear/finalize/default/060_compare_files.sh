
# Skip when there are no checksums:
test -s $VAR_DIR/layout/config/files.md5sum || return 0

LogPrint "Checking if restored files may not match the recreated system"
if ! chroot $TARGET_FS_ROOT md5sum -c --quiet < $VAR_DIR/layout/config/files.md5sum 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 ) ; then
    LogPrintError "Error: Restored files do not match the recreated system in $TARGET_FS_ROOT"
    return 1
fi
