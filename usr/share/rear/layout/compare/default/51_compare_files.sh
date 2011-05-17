# Compare files that could have an impact on the rescue image
if [ -e $VAR_DIR/layout/config/files.md5sum ] ; then
    if ! md5sum --check $VAR_DIR/layout/config/files.md5sum >&2; then
        LogPrint "Configuration files have changed."
        EXIT_CODE=1
    fi
fi
