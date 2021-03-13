
# Include utilities needed to get and set capabilities:

# Skip when the whole NETFS_RESTORE_CAPABILITIES array is empty.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}" because
# the test should succeed when there is any non-empty array member, not necessarily the first one:
if ! test "${NETFS_RESTORE_CAPABILITIES[*]}" ; then
    # Avoid a bug in the subsequent rescue/NETFS/default/600_store_NETFS_variables.sh script
    # that would store a false NETFS_RESTORE_CAPABILITIES='()' into /etc/rear/rescue.conf
    # when NETFS_RESTORE_CAPABILITIES=() but '()' is not an empty array but the string "()"
    # cf. https://github.com/rear/rear/pull/1284#issuecomment-293246380
    NETFS_RESTORE_CAPABILITIES=( 'No' )
    return 0
fi
# Be backward compatible:
is_false "$NETFS_RESTORE_CAPABILITIES" && return 0

REQUIRED_PROGS+=( getcap setcap )

