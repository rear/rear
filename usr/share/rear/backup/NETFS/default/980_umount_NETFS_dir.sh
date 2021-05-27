# umount NETFS mountpoint

if [[ "$BACKUP_UMOUNTCMD" ]] ; then
    BACKUP_URL="var://BACKUP_UMOUNTCMD"
fi

umount_url $BACKUP_URL $BUILD_DIR/outputfs
