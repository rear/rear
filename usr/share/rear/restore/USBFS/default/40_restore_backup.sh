# restore backup
#


Log "Restoring archive '$backuparchive'"

ProgressStart "Restoring from '$displayarchive'"
case "$BACKUP_PROG" in
	# tar compatible programms here
	tar)
		$BACKUP_PROG --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS \
			-C /mnt/local/ -x -f "$backuparchive"
	;;
	*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE /mnt/local \
			$BACKUP_PROG_OPTIONS $backuparchive
	;;
esac 1>&8
RETVAL=$?
ProgressStop
test $RETVAL -gt 0 && LogPrint "WARNING !
There was an error (Nr. $RETVAL) while restoring the archive. 
Please check '$LOGFILE' for more information. You should also
manually check the restored system to see wether it is complete.
"

