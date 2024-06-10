# umount ISO mountpoint

if [[ "$OUTPUT_UMOUNTCMD" ]] ; then
    OUTPUT_URL="var://OUTPUT_UMOUNTCMD"
fi

if [[ -z "$OUTPUT_URL" ]] ; then
    return
fi

umount_url "$OUTPUT_URL" $BUILD_DIR/outputfs
