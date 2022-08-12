#
# Move away restored files or directories that should not have been restored:
#
# See https://github.com/rear/rear/issues/779
#
# After backup restore ReaR should move away files or directories
# that should not have been restored - maily files or directories
# that are created and maintained by system tools where
# a restore from the backup results wrong/outdated
# content that conflicts with the actual system.
#
# The generic traditional example of such a file was /etc/mtab.
# As long as it was a regular file it must not have been restored
# with outdated content from a backup. Nowadays it is a symbolic link
# to /proc/self/mounts which should probably be restored to ensure
# that link is available.
#
# ReaR will not remove any file (any user data is sacrosanct).
# Instead ReaR moves those files away into a ReaR-specific directory
# (specified by BACKUP_RESTORE_MOVE_AWAY_DIRECTORY in default.conf)
# so that the admin can inspect that directory to see what ReaR thinks
# should not have been restored.
#
# There is nothing hardcoded in the scripts.
# Instead BACKUP_RESTORE_MOVE_AWAY_FILES is a documented predefined list
# in default.conf what files or directories are moved away by default.

# Go to the recovery system root directory:
pushd $TARGET_FS_ROOT >/dev/null
# Artificial 'for' clause that is run only once to be able to 'continue' in case of errors
# (because the 'for' loop is run only once 'continue' is the same as 'break'):
for dummy in "once" ; do
    # The following code is only meant to be used for the "recover" workflow:
    test "recover" = "$WORKFLOW" || continue
    # Nothing to do if the BACKUP_RESTORE_MOVE_AWAY_FILES list is empty
    # (that list is considered to be empty when its first element is empty):
    test "$BACKUP_RESTORE_MOVE_AWAY_FILES" || continue
    # Strip leading '/' from $BACKUP_RESTORE_MOVE_AWAY_DIRECTORY
    # to get a relative path that is needed inside the recovery system:
    move_away_dir="${BACKUP_RESTORE_MOVE_AWAY_DIRECTORY#/}"
    # Do nothing if no real BACKUP_RESTORE_MOVE_AWAY_DIRECTORY is specified
    # (it has to be specified in default.conf and must not be only '/'):
    test "$move_away_dir" || continue
    # Create the move away directory with mode 0700 (rwx------)
    # so that only root can access files and subdirectories therein
    # because the files therein could contain security relevant information:
    mkdir -p -m 0700 $move_away_dir || continue
    # Copy each file or directory in BACKUP_RESTORE_MOVE_AWAY_FILES with full path:
    for file in "${BACKUP_RESTORE_MOVE_AWAY_FILES[@]}" ; do
        # Strip leading '/' from $file to get it with relative path that is needed inside the recovery system:
        file_relative="${file#/}"
        # Skip files or directories listed in BACKUP_RESTORE_MOVE_AWAY_FILES that do not actually exist:
        test -e $file_relative || continue
        # Clean up already existing stuff in the move away directory
        # that would be (partially) overwritten by the current copy
        # (such stuff is considered as outdated leftover e.g. from a previous recovery)
        # but keep already existing stuff in the move away directory
        # that is not in the curent BACKUP_RESTORE_MOVE_AWAY_FILES list:
        rm -rf $move_away_dir/$file_relative
        # Copy the file or directory:
        cp -a --parents $file_relative $move_away_dir || continue
        # Only if the copy was successful remove the original file or directory content
        # but keep the original (empty) directory (for the reason see default.conf):
        if test -d $file_relative ; then
            # remove all files in the directory other than '.' and '..'
            # (avoids scaring stderr message: "rm: refusing to remove '.' or '..' directory")
            # * matches non-dot-files
            # .[!.]* matches dot-files except '.' and dot-dot-files
            # ..?* matches dot-dot-files (also dot-dot-...-dot-files) except '..'
            # If all patterns match nothing the nullglob setting in ReaR let it expand to empty
            # which is o.k. because 'rm -f' does not care about non-existent arguments:
            rm -rf $file_relative/* $file_relative/.[!.]* $file_relative/..?*
        else
            rm -rf $file_relative
        fi
    done
done
# Go back from the recovery system root directory:
popd >/dev/null

