
# Skip when there are no checksums:
test -s $VAR_DIR/layout/config/files.md5sum || return 0

LogPrint "Checking if certain restored files are consistent with the recreated system"
DebugPrint "See $VAR_DIR/layout/config/files.md5sum what files are checked"
local md5sum_stdout
# The exit status of the assignment is the exit status of the command substitution
# which is usually the exit status of 'md5sum' that is forwared by 'chroot'
# except 'chroot' fails (e.g. with 127 if 'md5sum' cannot be found).
# Because the redirections are done before chroot is run
# (in chroot plain 'md5sum -c --quiet' is run with redirected stdin)
# the 'md5sum' stdin comes from VAR_DIR/layout/config/files.md5sum in the recovery system.
# The 'md5sum' stdout messages like
#   /path/to/this: FAILED
#   /path/to/that: FAILED open or read
# provide sufficient information so we do not output 'md5sum' stderr messages like
#   md5sum: /path/to/that: No such file or directory
#   md5sum: WARNING: 1 line is improperly formatted
#   md5sum: WARNING: 1 listed file could not be read
#   md5sum: WARNING: 1 computed checksum did NOT match
# on the user's terminal but have them only in the log file as usual via stderr:
if ! md5sum_stdout="$( chroot $TARGET_FS_ROOT md5sum -c --quiet < $VAR_DIR/layout/config/files.md5sum )" ; then
    LogPrintError "Restored files in $TARGET_FS_ROOT do not fully match the recreated system"
    LogPrintError "(files in the backup are not same as when the ReaR rescue/recovery system was made)"
    # This 'sed' call must not be done in the above command substitution as a pipe
    # because then the command substitution exit status would be the one of 'sed'.
    # Prefix the reported files in the 'md5sum' stdout lines with '/mnt/local'
    # because this is the right path for the user in the currently running ReaR recovery system
    # for the restored files that do not match the md5sums that were saved at "rear mkrescue" time,
    # cf. https://github.com/rear/rear/pull/2954#issuecomment-1467645338 and subsequent comments.
    # The 'md5sum' stdout lines that report files start with '/' because
    # var/lib/rear/layout/config/files.md5sum contains file names with full path.
    # Prefix all 'md5sum' stdout lines with two spaces indentation
    # for better readability what the 'md5sum' stdout lines are:
    LogPrintError "$( sed -e "s|^/|$TARGET_FS_ROOT/|" -e 's/^/  /' <<< "$md5sum_stdout" )"
    LogPrintError "Manually check if those changed files cause issues in your recreated system"
    return 1
fi
