# Ask the user to confirm the layout given is final.

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

read 2>&1 -p "Please confirm that the layout in $VAR_DIR/layout/disklayout.conf has been adapted and has to be re-installed, by typing \"Yes\": "

if [ $REPLY != "Yes" ] ; then
    restore_backup $LAYOUTFILE
    Error "Layout list not confirmed."
fi
