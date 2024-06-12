if [[ "$BACKUP_MOUNTCMD" ]] ; then
    BACKUP_URL="var://BACKUP_MOUNTCMD"
fi

mount_url "$BACKUP_URL" "$BUILD_DIR/outputfs" $BACKUP_OPTIONS
