# 400_restore_duplicity.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# Restore from remote backup via DUPLICIY over rsync

if [ "$BACKUP_PROG" = "duplicity" ]; then

    LogPrint "========================================================================"
    LogPrint "Restoring backup with $BACKUP_PROG from '$BACKUP_DUPLICITY_URL'"
    LogPrint "========================================================================"

    # Ask for Passphrase if variable BACKUP_DUPLICITY_ASK_PASSPHRASE=1
    if is_true "$BACKUP_DUPLICITY_ASK_PASSPHRASE" ; then
        read -s -t $WAIT_SECS -r -p "Enter 'Passphrase' for the restore [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
        # when REPLY is empty (perhaps due timeout?) we will abort
        test -z "${REPLY}" && Error "Duplicity restore aborted due to missing 'Passphrase'"
        BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE="$REPLY"
    fi
    if [[ -n "$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE" ]] ; then
        # we have a encryption passphrase defined (by asking or by configuration)
        export PASSPHRASE="$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE"
    fi

    #export PYTHONHOME=/usr/lib64/python2.6
    #export PYTHONPATH=/usr/lib64/python2.6:/usr/lib64/python2.6/lib-dynload:/usr/lib64/python2.6/site-packages:/usr/lib64/python2.6/site-packages/duplicity
    export HOSTNAME=$(hostname)

    if [[ -n "$BACKUP_DUPLICITY_GPG_ENC_KEY" ]]; then
        GPG_KEY="--encrypt-key $BACKUP_DUPLICITY_GPG_ENC_KEY"
    fi

    starttime=$SECONDS

    # ensure we have enougth space to unpack the backups (they are 100M, but neet up to 1G to unpack!)
    if is_true "$BACKUP_DUPLICITY_TEMP_RAMDISK" ; then
        mkdir -p /mnt/tmp
        mount -t tmpfs none /mnt/tmp -o size=100%
        DUPLICITY_TEMPDIR=/mnt/tmp
    else
        DUPLICITY_TEMPDIR="$( mktemp -d -p $TARGET_FS_ROOT rear-duplicity.XXXXXXXXXXXXXXX || Error 'Could not create Temporary Directory for Duplicity' )"
    fi
	
    # Duplicity also saves some big files in $HOME
    HOME_TMP="$HOME"
    HOME="$DUPLICITY_TEMPDIR"
	
    LogPrint "Logging to $TMP_DIR/duplicity-restore.log"
    if [[ -n "${BACKUP_DUPLICITY_GPG_OPTIONS}" ]] ; then
        LogPrint "with CMD: $DUPLICITY_PROG -v 5 $GPG_KEY --gpg-options ${BACKUP_DUPLICITY_GPG_OPTIONS} --force --tempdir=$DUPLICITY_TEMPDIR $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT"
        $DUPLICITY_PROG -v 5 $GPG_KEY --gpg-options "${BACKUP_DUPLICITY_GPG_OPTIONS}" --force --tempdir="$DUPLICITY_TEMPDIR" $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT 0<&6 | tee $TMP_DIR/duplicity-restore.log
    else
        LogPrint "with CMD: $DUPLICITY_PROG -v 5 $GPG_KEY --force --tempdir=$DUPLICITY_TEMPDIR $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT"
        $DUPLICITY_PROG -v 5 $GPG_KEY --force --tempdir="$DUPLICITY_TEMPDIR" $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT 0<&6 | tee $TMP_DIR/duplicity-restore.log
    fi
    _rc=$?

    transfertime="$((SECONDS-$starttime))"
    sleep 1
	
    if [[ -d "$DUPLICITY_TEMPDIR" ]] ; then
        rm -rf "$DUPLICITY_TEMPDIR" || LogPrint "Could not remove Temporary Directory for Duplicity: $DUPLICITY_TEMPDIR"
    fi
    HOME="$HOME_TMP"
	
    #LogPrint "starttime = $starttime"
    #LogPrint "transfertime = $transfertime"

    LogPrint "========================================================================"


    if [ "$_rc" -gt 0 ]; then
        LogPrint "WARNING !
    There was an error while restoring the archive.
    Please check '$RUNTIME_LOGFILE' and $TMP_DIR/duplicity-restore.log for more information.
    You should also manually check the restored system to see whether it is complete.
    "

        _message="$(tail -14 ${TMP_DIR}/duplicity-restore.log)"

        LogPrint "Last 14 Lines of ${TMP_DIR}/duplicity-restore.log:"
        LogPrint "$_message"
    fi

    if [ $_rc -eq 0 ] ; then
        LogPrint "Restore completed in $transfertime seconds."
    fi

    LogPrint "========================================================================"

    # If /tmp was excluded we better check it exists on the $TARGET_FS_ROOT directory
    if [[ ! -d "$TARGET_FS_ROOT/tmp" ]] ; then
        mkdir -m 1777 "$TARGET_FS_ROOT/tmp"
        chown root:root "$TARGET_FS_ROOT/tmp"
    fi

    # Save the logfile to the recoverd filesystem for further checking
    LogPrint "Transferring Logfile $TMP_DIR/duplicity-restore.log to $TARGET_FS_ROOT/tmp/"
    cp -v $TMP_DIR/duplicity-restore.log $TARGET_FS_ROOT/tmp/
fi

