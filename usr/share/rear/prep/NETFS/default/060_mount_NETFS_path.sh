# create mount point
mkdir -p $v "$BUILD_DIR/outputfs" >&2
StopIfError "Could not mkdir '$BUILD_DIR/outputfs'"

AddExitTask "rmdir $v $BUILD_DIR/outputfs >&2"

if [[ "$BACKUP_MOUNTCMD" ]] ; then
    BACKUP_URL="var://BACKUP_MOUNTCMD"
fi

mount_url $BACKUP_URL $BUILD_DIR/outputfs $BACKUP_OPTIONS
