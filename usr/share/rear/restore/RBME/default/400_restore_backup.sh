if [[ -z "$RBME_BACKUP" ]] ; then
    Error "No RBME backup selected (BACKUP_URL?). Aborting."
fi

local backup_prog_rc

scheme=$(url_scheme "$BACKUP_URL")

LogPrint "Restoring from backup $RBME_BACKUP."
ProgressStart "Preparing restore operation"

(
case $scheme in
    (local|nfs)
        [[ -d $BUILD_DIR/outputfs/$RBME_HOSTNAME/$RBME_BACKUP ]]
        BugIfError "Backup $RBME_BACKUP not found in $BACKUP_URL$RBME_HOSTNAME/."
        rsync -aSH $BUILD_DIR/outputfs/$RBME_HOSTNAME/$RBME_BACKUP/* $TARGET_FS_ROOT/
        ;;
    *)
        return
        ;;
esac
# important trick: the backup prog is the last in each case entry and the case .. esac is the last command
# in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog!
) &

BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# make sure that we don't fall for an old size info
unset size
# while the restore runs in a sub-process, display some progress information to the user
test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
    size=$( df -P $TARGET_FS_ROOT | tail -1 | awk '{print $3}' )
    ProgressInfo "Restored $((size/1024)) MiB [avg $((size/(SECONDS-starttime))) KiB/sec]"
done

ProgressStop

transfertime="$((SECONDS-starttime))"

# harvest return code from background job. The kill -0 $BackupPID loop above should
# have made sure that this wait won't do any real "waiting" :-)
wait $BackupPID
backup_prog_rc=$?

sleep 1
test "$backup_prog_rc" -gt 0 && LogPrint "WARNING !
There was an error (${rsync_err_msg[$backup_prog_rc]}) while restoring the archive.
Please check '$RUNTIME_LOGFILE' for more information. You should also
manually check the restored system to see whether it is complete.
"
LogPrint "Restored $((size/1024)) MiB in $((transfertime)) seconds [avg $((size/transfertime)) KiB/sec]"
