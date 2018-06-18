### Restore from bareos
###

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

    else

        ### Bareos support using bextract and tape archive
        LogPrint "$REQUESTRESTORE_TEXT"

        LogPrint "The bextract command looks like:

   bextract$exclude_list -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE $TARGET_FS_ROOT

Where '$BEXTRACT_VOLUME' is the required Volume name of the tape,
alternatively, use '*' if you don't know the volume,
and '$BEXTRACT_DEVICE' is the Bareos device name of the tape drive.
"

        LogPrint "Please restore your backup in the provided shell, use the shell history to
access the above command and, when finished, type exit in the shell to continue recovery.
"
        rear_shell "Did you restore the backup to '$TARGET_FS_ROOT' ? Ready to continue ?" \
            "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE $TARGET_FS_ROOT"

    fi

else
    ### Bareos support using bconsole

    if [ "$BAREOS_RECOVERY_MODE" != "manual" ]
    then
        # restore most recent backup automatically

        if [ -z "$BAREOS_CLIENT" ]
        then
            BAREOS_CLIENT="$HOSTNAME-fd"
        fi

        if [ -n "$BAREOS_FILESET" ]
        then
            FILESET="fileset=\"$BAREOS_FILESET\""
        fi

        if [ -n "$BAREOS_RESTORE_JOB" ]
        then
            RESTOREJOB="restorejob=$BAREOS_RESTORE_JOB"
        fi

        echo "restore client=$BAREOS_CLIENT $RESTOREJOB $FILESET where=$TARGET_FS_ROOT select all done

" |     bconsole

        # wait for job to start
        LogPrint "waiting for job to start"
        while true
        do
            sleep 3
            echo "status client=$BAREOS_CLIENT" | bconsole | egrep "^JobId.* running." && break
        done

        # wait for job to finish
        LogPrint "waiting for job to finish"
        while true
        do
            sleep 10
            echo "status client=$BAREOS_CLIENT" | bconsole | egrep "^No Jobs running" >/dev/null && break
        done
        LogPrint "Restore job finished."
    else

    # Prompt the user that the system recreation has been done and that
    # bconsole is about to be started.
        LogPrint "
The system is now ready for a restore via Bareos. bconsole will be started for
you to restore the required files. It's assumed that you know what is necessary
to restore - typically it will be a full backup.

Do not exit 'bconsole' until all files are restored

WARNING: The new root is mounted under '$TARGET_FS_ROOT'.

Press ENTER to start bconsole"
        read

        bconsole
    fi
    LogPrint "
Please verify that the backup has been restored correctly to '$TARGET_FS_ROOT'
in the provided shell. When finished, type exit in the shell to continue
recovery.
"

if [[ "$ISO_RECOVER_MODE" = "unattended" ]] || [[ "$PXE_RECOVER_MODE" = "unattended" ]] ; then
    Log "Unattended mode selected"
else
    rear_shell "Did the backup successfully restore to '$TARGET_FS_ROOT' ? Ready to continue ?" \
            "bls -j -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE
vi bootstrap.txt
bextract$exclude_list -b bootstrap.txt -V$BEXTRACT_VOLUME $BEXTRACT_DEVICE $TARGET_FS_ROOT"
fi

fi # end of [[ "$BEXTRACT_DEVICE" || "$BEXTRACT_VOLUME" ]]


mkdir $TARGET_FS_ROOT/var/lib/bareos && chroot $TARGET_FS_ROOT chown bareos: /var/lib/bareos

LogPrint "Bareos restore finished."

# continue with next script
