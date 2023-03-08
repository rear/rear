
# Skip when there are no checksums:
test -s $VAR_DIR/layout/config/files.md5sum || return 0

local md5sum_output
# The exit status of the assignment is the exit status of the command substitution
# which is usually the exit status of 'md5sum' that is forwared by 'chroot'
# except 'chroot' fails (e.g. with 127 if 'md5sum' cannot be found).
# Because the redirections are done before chroot is run
# (in chroot plain 'md5sum -c --quiet' is run with redirected stdin and stderr)
# the 'md5sum' stdin comes from VAR_DIR/layout/config/files.md5sum in the recovery system:
if ! md5sum_output="$( chroot $TARGET_FS_ROOT md5sum -c --quiet < $VAR_DIR/layout/config/files.md5sum 2>&1 )" ; then
    LogPrintError "Error: Restored files do not match the recreated system in $TARGET_FS_ROOT"
    # Add two spaces indentation for better readability what the 'md5sum' output lines are.
    # This 'sed' call must not be done in the above command substitution as a pipe
    # because then the command substitution exit status would be the one of 'sed'.
    LogPrintError "$( sed -e 's/^/  /' <<< "$md5sum_output" )"
    return 1
fi
