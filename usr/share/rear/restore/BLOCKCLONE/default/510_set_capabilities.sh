
# Restore capabilities:

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
test "${NETFS_RESTORE_CAPABILITIES[*]}" || return 0
# Be backward compatible:
is_false "$NETFS_RESTORE_CAPABILITIES" && return 0

# Try to find a capabilities file.
# Prefer the one in the recovery system ($VAR_DIR/recovery/capabilities) if exists
# over the one that may have been restored from the backup ($TARGET_FS_ROOT/$VAR_DIR/recovery/capabilities):
test -s $TARGET_FS_ROOT/$VAR_DIR/recovery/capabilities && capabilities_file="$TARGET_FS_ROOT/$VAR_DIR/recovery/capabilities"
test -s $VAR_DIR/recovery/capabilities && capabilities_file="$VAR_DIR/recovery/capabilities"

# Report when NETFS_RESTORE_CAPABILITIES is non-empty but there is no capabilities file:
if ! test "$capabilities_file" ; then
    LogPrint "Cannot restore capabilities: No $VAR_DIR/recovery/capabilities or it is empty"
    # Do not abort the whole 'rear recover' in this case:
    return 0
fi

LogPrint "Restoring file capabilities (NETFS_RESTORE_CAPABILITIES)"
while IFS="=" read file cap ; do
    file="${file% }"
    cap="${cap# }"
    setcap "${cap}" "${TARGET_FS_ROOT}/${file}" 1>/dev/null || LogPrint "Error while setting capabilties to '$file'"
done < <(cat $capabilities_file)

