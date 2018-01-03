# 400_restore_duplicity.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# Restore from remote backup via DUPLICIY over rsync

if [ "$BACKUP_PROG" = "duplicity" ]; then

    LogPrint "========================================================================"
    LogPrint "Restoring backup with $BACKUP_PROG from $DUPLICITY_HOST/$DUPLICITY_PATH/$(hostname)"
    LogPrint "========================================================================"

    # Ask for Confirmation only if Password is already given
    if [ -z "$BACKUP_DUPLICITY_ASK_PASSPHRASE" ]; then
		read -p "ENTER for start restore: " 0<&6 1>&7 2>&8
		export PASSPHRASE="$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE"
	fi

    #export PYTHONHOME=/usr/lib64/python2.6
    #export PYTHONPATH=/usr/lib64/python2.6:/usr/lib64/python2.6/lib-dynload:/usr/lib64/python2.6/site-packages:/usr/lib64/python2.6/site-packages/duplicity
    export HOSTNAME=$(hostname)

    GPG_OPT="$BACKUP_DUPLICITY_GPG_OPTIONS"
    if [ -n "$BACKUP_DUPLICITY_GPG_ENC_KEY" ]; then
		GPG_KEY="--encrypt-key $BACKUP_DUPLICITY_GPG_ENC_KEY"
    fi

    starttime=$SECONDS

    # ensure we have enougth space to unpack the backups (they are 100M, but neet up to 1G to unpack!)
    if [ -n "$BACKUP_DUPLICITY_TEMP_RAMDISK" ]; then
		mkdir -p /mnt/tmp
		mount -t tmpfs none /mnt/tmp -o size=100%
		DUPLICITY_TEMPDIR=/mnt/tmp
	else
		DUPLICITY_TEMPDIR="$( mktemp -d -p $TARGET_FS_ROOT rear-duplicity.XXXXXXXXXXXXXXX || Error 'Could not create Temporary Directory for Duplicity' )"
	fi
	
	#Duplicity also saves some big files in $HOME
	HOME_TMP="$HOME"
	HOME="$DUPLICITY_TEMPDIR"
	
    LogPrint "with CMD: $DUPLICITY_PROG -v 5 $GPG_OPT $GPG_KEY --force --tempdir=$DUPLICITY_TEMPDIR $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT"
    LogPrint "Logging to $TMP_DIR/duplicity-restore.log"
    $DUPLICITY_PROG -v 5 $GPG_OPT $GPG_KEY --force --tempdir="$DUPLICITY_TEMPDIR" $BACKUP_DUPLICITY_URL/$HOSTNAME/ $TARGET_FS_ROOT 0<&6 | tee $TMP_DIR/duplicity-restore.log
    _rc=$?

    transfertime="$((SECONDS-$starttime))"
    sleep 1
	
	rm -rf "$DUPLICITY_TEMPDIR" || Error "Could not remove Temporary Directory for Duplicity: $DUPLICITY_TEMPDIR"
	HOME="$HOME_TMP"
	
    #LogPrint "starttime = $starttime"
    #ogPrint "transfertime = $transfertime"

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
            LogPrint "Restore comleted in $transfertime seconds."
    fi

    LogPrint "========================================================================"

    # Save the logfile to the recoverd filesystem for further checking
    LogPrint "Transferring Logfile $TMP_DIR/duplicity-restore.log to $TARGET_FS_ROOT/tmp/"
    cp -v $TMP_DIR/duplicity-restore.log $TARGET_FS_ROOT/tmp/
fi

