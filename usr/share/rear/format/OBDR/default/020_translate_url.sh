### Backwards compatibility with NETFS_URL and ISO_URL

if [[ "$NETFS_URL" ]] ; then
    Log "Using NETFS_URL is deprecated. Use BACKUP_URL instead."
    BACKUP_URL=$NETFS_URL
fi

if [[ "$NETFS_MOUNTCMD" ]] ; then
    BACKUP_MOUNTCMD=$NETFS_MOUNTCMD
fi

if [[ "$NETFS_UMOUNTCMD" ]] ; then
    BACKUP_UMOUNTCMD=$NETFS_UMOUNTCMD
fi

if [[ "$NETFS_OPTIONS" ]] ; then
    BACKUP_OPTIONS=$NETFS_OPTIONS
fi

if [[ "$RSYNC_URL" ]] ; then
    Log "Using RSYNC_URL is deprecated. Use BACKUP_URL instead."
    BACKUP_URL=$RSYNC_URL
fi

test "$RSYNC_OPTIONS" && Error "RSYNC_OPTIONS is no longer supported. Use BACKUP_RSYNC_OPTIONS instead."

if [[ "$ISO_URL" ]] ; then
    Log "Using ISO_URL is deprecated. Use OUTPUT_URL instead."
    OUTPUT_URL=$ISO_URL
fi

if [[ "$ISO_MOUNTCMD" ]] ; then
    OUTPUT_MOUNTCMD=$ISO_MOUNTCMD
fi

if [[ "$ISO_UMOUNTCMD" ]] ; then
    OUTPUT_UMOUNTCMD=$ISO_UMOUNTCMD
fi

if [[ "$ISO_OPTIONS" ]] ; then
    OUTPUT_OPTIONS=$ISO_OPTIONS
fi

### Make sure we have OUTPUT_* from BACKUP_*, for compat with versions that
### not separated the two.

if [[ -z "$OUTPUT_OPTIONS" ]] ; then
    if [[ -z "$OUTPUT_URL" && -z "$OUTPUT_MOUNTCMD" ]] ; then
        ### There can be cases where it's intentionally empty.
        OUTPUT_OPTIONS=$BACKUP_OPTIONS
    fi
fi

if [[ -z "$OUTPUT_URL" ]] ; then
    if [[ "$USB_DEVICE" ]] ; then
        OUTPUT_URL="usb://$USB_DEVICE"
    elif [[ -z "$OUTPUT_MOUNTCMD" ]] ; then
        OUTPUT_URL=$BACKUP_URL
    fi
fi

if [[ -z "$OUTPUT_MOUNTCMD" ]] ; then
    if [[ -z "$OUTPUT_URL" ]] ; then
        OUTPUT_MOUNTCMD=$BACKUP_MOUNTCMD
    fi
fi

if [[ -z "$OUTPUT_UMOUNTCMD" ]] ; then
    if [[ -z "$OUTPUT_URL" && -z "$OUTPUT_MOUNTCMD" ]] ; then
        OUTPUT_UMOUNTCMD=$BACKUP_UMOUNTCMD
    fi
fi
