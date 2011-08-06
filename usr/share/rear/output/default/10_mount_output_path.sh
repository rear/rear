# create mount point
mkdir -p $v "$BUILD_DIR/outputfs" >&2
StopIfError "Could not mkdir '$BUILD_DIR/outputfs'"

AddExitTask "rmdir $v $BUILD_DIR/outputfs >&2"

if [[ "$ISO_MOUNTCMD" ]] ; then
    ISO_URL="var://ISO_MOUNTCMD"
fi

if [[ -z "$ISO_URL" ]] ; then
    return
fi

mount_url $ISO_URL $BUILD_DIR/outputfs
