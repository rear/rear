
# Save all found capapilities.

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
test "${NETFS_RESTORE_CAPABILITIES[*]}" || return 0
# Be backward compatible:
is_false "$NETFS_RESTORE_CAPABILITIES" && return 0

# Save capapilities to /var/lib/rear/recovery/capabilities:
cat /dev/null > $VAR_DIR/recovery/capabilities

# getcap and setcap are mandatory when NETFS_RESTORE_CAPABILITIES has a non-empty array member:
has_binary getcap && has_binary setcap || Error "getcap and setcap are needed when NETFS_RESTORE_CAPABILITIES is non-empty"

# Empty values must be avoided for egrep -v because egrep -v '' or egrep -v 'something|' matches all:
exclude_directories="$BUILD_DIR"
test "$ISO_DIR" && exclude_directories="$exclude_directories|$ISO_DIR"

# Be backward compatible:
is_true "$NETFS_RESTORE_CAPABILITIES" && NETFS_RESTORE_CAPABILITIES=( '/' )

# The actual work:
LogPrint "Saving file capabilities (NETFS_RESTORE_CAPABILITIES)"
for directory in "${NETFS_RESTORE_CAPABILITIES[@]}" ; do
    # Ignore stderr to avoid thousands of 'Failed to get capabilities of file'
    # stderr messages for directories like /proc /sys /dev in case of 'getcap -r /':
    getcap -r $directory 2>/dev/null | egrep -v "$exclude_directories" >> $VAR_DIR/recovery/capabilities
done

