
# Restore capabilities:

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
test "${NETFS_RESTORE_CAPABILITIES[*]}" || return 0

# Report when NETFS_RESTORE_CAPABILITIES is non-empty but there is no capabilities file:
if ! test -s $VAR_DIR/recovery/capabilities ; then
    LogPrint "Cannot restore capabilities: No $VAR_DIR/recovery/capabilities or it is empty"
fi

LogPrint "Restoring capabilities (NETFS_RESTORE_CAPABILITIES)"
while IFS="=" read file cap ; do
    file="${file% }"
    cap="${cap# }"
    setcap "${cap}" "${TARGET_FS_ROOT}/${file}" 1>/dev/null || LogPrint "Error while setting capabilties to '$file'"
done < <(cat $VAR_DIR/recovery/capabilities)

