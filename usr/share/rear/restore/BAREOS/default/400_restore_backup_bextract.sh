#
# Restore from Bareos using bextract (optional)
#

if [ "$BAREOS_RESTORE_MODE" != "bextract" ]; then
    return
fi
local exclude_list=()
if [[ -s "$TMP_DIR/restore-exclude-list.txt" ]]; then
    exclude_list=" -e $TMP_DIR/restore-exclude-list.txt "
fi

if [[ -b "$BEXTRACT_DEVICE" && -d "/backup" ]]; then

    ### Bareos support using bextract and disk archive
    LogPrint "
The system is now ready to restore from Bareos. bextract will be started for
you to restore the required files. It's assumed that you know what is
necessary to restore - typically it will be a full backup.

Do not exit 'bextract' until all files are restored.

Be aware, that the target system is mounted at '$TARGET_FS_ROOT'.
"
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -p "Press ENTER to start bextract" 0<&6 1>&7 2>&8

    bextract$exclude_list -V$BEXTRACT_VOLUME /backup $TARGET_FS_ROOT

    LogPrint "
Please verify that the backup has been restored correctly to '$TARGET_FS_ROOT'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"
    rear_shell "Did the backup successfully restore to '$TARGET_FS_ROOT' ? Ready to continue ?" \
        "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE $TARGET_FS_ROOT"

fi
