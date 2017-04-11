
# Include utilities needed to get and set capabilities:

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
test "${NETFS_RESTORE_CAPABILITIES[*]}" || return 0

REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" getcap setcap )

