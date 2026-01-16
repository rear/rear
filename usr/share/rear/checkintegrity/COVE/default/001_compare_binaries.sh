# Check md5sum files
LogPrint "Checking if certain restored files are consistent with the recreated system"
local md5sum_stdout
for md5sum_file in files.md5sum cove-files.md5sum ; do
    # Skip when there are no checksums for this file:
    test -s "$VAR_DIR/layout/config/$md5sum_file" || continue
    
    DebugPrint "See $VAR_DIR/layout/config/$md5sum_file what files are checked"
    if ! md5sum_stdout="$( md5sum -c --quiet < $VAR_DIR/layout/config/$md5sum_file )" ; then
        LogPrintError "Restored files do not fully match the recreated system"
        LogPrintError "$( sed -e 's/^/  /' <<< "$md5sum_stdout" )"
        Error "Binary verification failed: checksums do not match for $md5sum_file"
    fi
done

LogPrint "Binary verification passed: all checksums match successfully"
