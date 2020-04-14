# Compare files that could have an impact on the rescue image
if [ -e $VAR_DIR/layout/config/files.md5sum ] ; then
    config_files=()
    for obj in "${CHECK_CONFIG_FILES[@]}" ; do
        if [ -d "$obj" ] ; then
            config_files+=( $( find "$obj" -type f ) )
        elif [ -e "$obj" ] ; then
            config_files+=( "$obj" )
        fi
    done
    md5sum "${config_files[@]}" > $TMP_DIR/files.md5sum
    if ! diff -u $TMP_DIR/files.md5sum $VAR_DIR/layout/config/files.md5sum ; then
        LogPrint "Configuration files have changed."
        EXIT_CODE=1
    fi
fi
