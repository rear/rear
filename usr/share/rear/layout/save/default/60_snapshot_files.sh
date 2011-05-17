# Save a hash of files that would warrant a new rescue image when changed.
if [ "$WORKFLOW" = "checklayout" ] ; then
    return 0
fi

for config in "${CHECK_CONFIG_FILES[@]}" ; do
    if [ -e "$config" ] ; then
        md5sum "$config" > $VAR_DIR/layout/config/$(basename "$config").md5sum
    else
        echo 0 > $VAR_DIR/layout/config/$(basename "$config").md5sum
        continue
    fi
done
