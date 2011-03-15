# Ask the user to confirm the generated script is ok

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

read 2>&1 -p "Please confirm that the script in $LAYOUT_CODE is a correct script to generate the disk layout, by typing \"Yes\": "

if [ $REPLY != "Yes" ] ; then
    restore_backup $LAYOUTFILE
    Error "Not proceeding. Script not OK."
fi

chmod +x $LAYOUT_CODE
