# create mount point
mkdir -p $v "$BUILD_DIR/outputfs" >&2
StopIfError "Could not mkdir '$BUILD_DIR/outputfs'"

AddExitTask "rmdir $v $BUILD_DIR/outputfs >&2"

if [[ "$OUTPUT_MOUNTCMD" ]] ; then
    OUTPUT_URL="var://$OUTPUT_MOUNTCMD"
fi

if [[ -z "$OUTPUT_URL" ]] ; then
    return
fi

mount_url $OUTPUT_URL $BUILD_DIR/outputfs $OUTPUT_OPTIONS
