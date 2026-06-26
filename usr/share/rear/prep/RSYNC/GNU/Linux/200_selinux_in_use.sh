# Detect rsync support for SELinux context preservation via --xattrs
# This script only runs when BACKUP_PROG is rsync

[[ "$(basename $BACKUP_PROG)" == "rsync" ]] || return

if grep -q "no xattrs" "$TMP_DIR/rsync_protocol" ; then
    local host
    host="$(rsync_host "$BACKUP_URL")"
    # no xattrs compiled in remote rsync, so saving SELinux attributes are not possible
    Log "WARNING: --xattrs not possible on system ($host) (no xattrs compiled in rsync)"
    # rsync does not support SELinux context preservation
    RSYNC_SELINUX=
else
    # if --xattrs is already set; no need to do it again
    if ! grep -q xattrs <<< "${BACKUP_RSYNC_OPTIONS[*]}" ; then
        BACKUP_RSYNC_OPTIONS+=( --xattrs )
    fi
    # rsync supports SELinux context preservation via --xattrs
    RSYNC_SELINUX=1
fi
