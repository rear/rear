# Save a hash of files that would warrant a new rescue image when changed.
if [ "$WORKFLOW" = "checklayout" ] ; then
    return 0
fi

: > $VAR_DIR/layout/config/files.md5sum

for config in "${CHECK_CONFIG_FILES[@]}" ; do
    if [ -e "$config" ] ; then
        echo "$(md5sum "$config")" >> $VAR_DIR/layout/config/files.md5sum
    else
        echo "$(echo 0 | md5sum | cut -d " " -f "1")  $config" >> $VAR_DIR/layout/config/files.md5sum
    fi
done
