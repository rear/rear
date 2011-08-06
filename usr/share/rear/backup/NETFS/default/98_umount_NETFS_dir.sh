# umount NETFS mountpoint

if [[ "$BACKUP_UMOUNTCMD" ]] ; then
    BACKUP_URL="var://BACKUP_UMOUNTCMD"
fi

umount_url $BACKUP_URL $BUILD_DIR/outputfs

rmdir $v $BUILD_DIR/outputfs >&2
if [[ $? -eq 0 ]] ; then
    # the argument to RemoveExitTask has to be identical to the one given to AddExitTask
    RemoveExitTask "rmdir $v $BUILD_DIR/outputfs >&2"
fi
