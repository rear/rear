if [[ "$OUTPUT_MOUNTCMD" ]] ; then
    OUTPUT_URL="var://$OUTPUT_MOUNTCMD"
fi

if [[ -z "$OUTPUT_URL" ]] ; then
    return
fi

mount_url "$OUTPUT_URL" "$BUILD_DIR/outputfs" $OUTPUT_OPTIONS
