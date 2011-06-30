#
# Something basic to get started - V1.0.
#
#
# restore from bacula
#
# Not much to do here. This is a manual restore in that we
# assume that the user knows how to run a restore from bacula and that they
# know what files to restore and to where.

if [[ "$BEXTRACT_DEVICE" || "$BEXTRACT_VOLUME" ]]; then

    if [[ -s "$TMP_DIR/restore-exclude-list.txt" ]]; then
        exclude_list=" -e $TMP_DIR/restore-exclude-list.txt "
    fi

    if [[ -b "$BEXTRACT_DEVICE" && -d "/backup" ]]; then

        ### Bacula support using bextract and disk archive
        LogPrint "The system is now ready for a restore via Bacula. bextract will
be started for you to restore the required files. It's assumed that you know
what is necessary to restore - typically it will be a full backup.
Be aware, the new root is mounted under /mnt/local.
Do not exit bextract until all files are restored.
"
        read -p "Press ENTER to start bextract" 2>&1

        bextract$exclude_list -V$BEXTRACT_VOLUME /backup /mnt/local

        LogPrint "
Please verify that the backup has been restored correctly to '/mnt/local'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"
        rear_shell "Did the backup successfully restore to '/mnt/local' ? Ready to continue ?" \
            "bextract$exclude_list -V$BEXTRACT_VOLUME /backup /mnt/local"

    else

        ### Bacula support using bextract and tape archive
        LogPrint "$REQUESTRESTORE_TEXT"

        LogPrint "The bextract command looks like:

   bextract$exclude_list -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local

Where \"$BEXTRACT_VOLUME\" is the required Volume name of the tape,
alternatively, use '*' if you don't know the volume,
and \"$BEXTRACT_DEVICE\" is the Bacula device name of the tape drive."

        LogPrint "Please restore your backup in the provided shell, use the shell history to
access the above command and, when finished, type exit in the shell to continue recovery.
"
        rear_shell "Did you restore the backup to /mnt/local ? Ready to continue ?" \
            "bextract$exclude_list -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local"

    fi

else

    ### Bacula support using bconsole

    # Prompt the user that the system recreation has been done and that
    # bconsole is about to be started.
    echo "The system is now ready for a restore via Bacula. bconsole will
be started for you to restore the required files. It's assumed that you know
what is necessary to restore - typically it will be a full backup.
Be aware, the new root is mounted under '/mnt/local'.
Do not exit bconsole until all files are restored

Press ENTER to start bconsole"
    read

    bconsole

    LogPrint "
Please verify that the backup has been restored correctly to '/mnt/local'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"
    cat <<EOF | rear_shell "Did the backup successfully restore to '/mnt/local' ? Ready to continue ?"
bextract$exclude_list -V$BEXTRACT_VOLUME /backup /mnt/local
EOF

fi

# continue with next script
