
# Save all found capapilities.

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
test "${NETFS_RESTORE_CAPABILITIES[*]}" || return 0

# Save capapilities to /var/lib/rear/recovery/capabilities:
echo /dev/null > $VAR_DIR/recovery/capabilities

# getcap and setcap are mandatory when NETFS_RESTORE_CAPABILITIES has a non-empty array member:
has_binary getcap && has_binary setcap || Error "getcap and setcap are needed when NETFS_RESTORE_CAPABILITIES is non-empty"

for directory in "${NETWORKING_PREPARATION_COMMANDS[@]}" ; do
    getcap -r $directory 2>/dev/null | egrep -v "$TMPDIR|$ISO_DIR" >> $VAR_DIR/recovery/capabilities
done

