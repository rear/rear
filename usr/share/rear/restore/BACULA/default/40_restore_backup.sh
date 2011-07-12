### Restore from bacula
###

### Create example bootstrap file
cat <<EOF >$VAR_DIR/bootstrap.txt
### Example Bacula bootstrap file
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

if [[ "$BEXTRACT_DEVICE" || "$BEXTRACT_VOLUME" ]]; then

    if [[ -s "$TMP_DIR/restore-exclude-list.txt" ]]; then
        exclude_list=" -e $TMP_DIR/restore-exclude-list.txt "
    fi

    if [[ -b "$BEXTRACT_DEVICE" && -d "/backup" ]]; then

        ### Bacula support using bextract and disk archive
        LogPrint "
The system is now ready to restore from Bacula. bextract will be started for
you to restore the required files. It's assumed that you know what is
necessary to restore - typically it will be a full backup.

Do not exit 'bextract' until all files are restored.

WARNING: The new root is mounted under '/mnt/local'.
"
        read -p "Press ENTER to start bextract" 2>&1

        bextract$exclude_list -V$BEXTRACT_VOLUME /backup /mnt/local

        LogPrint "
Please verify that the backup has been restored correctly to '/mnt/local'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"
        rear_shell "Did the backup successfully restore to '/mnt/local' ? Ready to continue ?" \
            "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local"

    else

        ### Bacula support using bextract and tape archive
        LogPrint "$REQUESTRESTORE_TEXT"

        LogPrint "The bextract command looks like:

   bextract$exclude_list -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local

Where \"$BEXTRACT_VOLUME\" is the required Volume name of the tape,
alternatively, use '*' if you don't know the volume,
and \"$BEXTRACT_DEVICE\" is the Bacula device name of the tape drive.
"

        LogPrint "Please restore your backup in the provided shell, use the shell history to
access the above command and, when finished, type exit in the shell to continue recovery.
"
        rear_shell "Did you restore the backup to /mnt/local ? Ready to continue ?" \
            "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local"

    fi

else

    ### Bacula support using bconsole

    # Prompt the user that the system recreation has been done and that
    # bconsole is about to be started.
    LogPrint "
The system is now ready for a restore via Bacula. bconsole will be started for
you to restore the required files. It's assumed that you know what is necessary
to restore - typically it will be a full backup.

Do not exit 'bconsole' until all files are restored

WARNING: The new root is mounted under '/mnt/local'.

Press ENTER to start bconsole"
    read

    bconsole

    LogPrint "
Please verify that the backup has been restored correctly to '/mnt/local'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"
    rear_shell "Did the backup successfully restore to '/mnt/local' ? Ready to continue ?" \
            "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local"

fi

# continue with next script
