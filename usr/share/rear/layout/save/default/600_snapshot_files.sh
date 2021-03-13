# Save a hash of files that would warrant a new rescue image when changed.
if [ "$WORKFLOW" = "checklayout" ] ; then
    return 0
fi

config_files=()
for obj in "${CHECK_CONFIG_FILES[@]}" ; do
    if [ -d "$obj" ] ; then
        config_files+=( $( find "$obj" -type f ) )
    elif [ -e "$obj" ] ; then
        config_files+=( "$obj")
    fi
done
md5sum "${config_files[@]}" > $VAR_DIR/layout/config/files.md5sum
