# Compare files that could have an impact on the rescue image
for config in "${CHECK_CONFIG_FILES[@]}" ; do
    orig_value=$(cat $VAR_DIR/layout/config/$(basename "$config").md5sum)
    if [ -z "$orig_value" ] ; then
        LogPrint "File $config has changed."
        EXIT_CODE=1
    fi

    if [ -e "$config" ] ; then
        new_value=$(md5sum "$config")
        if [ "$new_value" != "$orig_value" ] ; then
            LogPrint "File $config has changed."
            EXIT_CODE=1
        fi
    else
        if [ "$orig_value" != "0" ] ; then
            LogPrint "File $config has changed."
            EXIT_CODE=1
        fi
    fi
done
