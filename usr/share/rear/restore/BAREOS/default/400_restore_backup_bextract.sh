#
# Restore from Bareos using bextract (optional)
#

### Create example bootstrap file
cat <<EOF >$VAR_DIR/bootstrap.txt
### Example Bareos bootstrap file
###

### Only the exact Volume name is required, other keywords are optional.
### The use of FileIndex and Count keywords speeds up the selection enormously.

### The Volume name to use
Volume=PLEASE-EDIT-BOOTSTRAP

### A (list of) Client name(s) to be matched on the current Volume
#Client=$(hostname -s)-fd

### A (list or range of) JobId(s) to be selected from the current Volume
#JobId=18

### A (list of) Job name(s) to be matched on the current Volume
#Job=Bkp_Daily.2011-06-16

### A (list or range of) Volume session id(s) to be matched from the current Volume
#VolSessionId=1

### The Volume session time to be matched from the current Volume
#VolSessionTime=108927638

### A (list or range of) FileIndex(es) to be selected from the current Volume
#FileIndex=1-157

### The total number of files that will be restored for this Volume.
#Count=157
EOF
#############################################################################

if [[ "$BEXTRACT_DEVICE" || "$BEXTRACT_VOLUME" ]]; then

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

WARNING: The new root is mounted under '$TARGET_FS_ROOT'.
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

fi
