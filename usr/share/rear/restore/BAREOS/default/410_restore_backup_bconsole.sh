#
# Restore from Bareos using bconsole (optional)
#

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then
    # restore using bextract is handled in another script.
   return
fi

get_last_restore_jobid()
{
    echo "llist jobs ${RESTOREJOB_AS_JOB} client=$BAREOS_CLIENT jobtype=R last" | bconsole | sed -r -n 's/ +jobid: //p'
}

#
# wait_restore_job():
#
#   return code:
#     0: OK
#     1: OK with warnings
#     >1: Error
#
#  Also sets RESTORE_JOBID to the jobid of the restore job.
#
wait_restore_job()
{
    local last_restore_jobid_old="$1"
    unset RESTORE_JOBID

    while true; do
        local last_restore_jobid=$(get_last_restore_jobid)
        if [ "${last_restore_jobid}" ] && [ "${last_restore_jobid}" != "${last_restore_jobid_old}" ]; then
            RESTORE_JOBID=${last_restore_jobid}
            Log "restore exists (${last_restore_jobid}) and differs from previous (${last_restore_jobid_old})."
            LogPrint "$(bconsole <<< "list jobid=${last_restore_jobid}")"
            LogPrint "waiting for restore job ${last_restore_jobid} to finish."
            local last_restore_wait=$(printf ".api 2\nwait jobid=${last_restore_jobid}\n" | bconsole)
            Log "${last_restore_wait}"
            LogPrint "$(bconsole <<< "list jobid=${last_restore_jobid}")"
            local last_restore_exitstatus=$(sed -n -r 's/ *"exitstatus": ([0-9]+)[,]?/\1/p' <<< "${last_restore_wait}")
            return ${last_restore_exitstatus}
        fi
        sleep 1
    done
}

# get last restore jobid before starting the restore
local last_restore_jobid_old=$(get_last_restore_jobid)

echo "status client=$BAREOS_CLIENT" | bconsole > $TMP_DIR/bareos_client_status_before_restore.txt
LogPrint "$(cat $TMP_DIR/bareos_client_status_before_restore.txt)"

RESTORE_CMD="restore client=$BAREOS_CLIENT $RESTORECLIENT $RESTOREJOB $FILESET where=$TARGET_FS_ROOT select all done yes"

UserOutput ""
UserOutput "The system is now ready for a restore via Bareos."
UserOutput ""
UserOutput "When choosing 'automatic' a Bareos restore without user interaction"
UserOutput "will be started with following options:"
UserOutput "${RESTORE_CMD}"
UserOutput ""
UserOutput "When choosing 'manual', bconsole will be started"
UserOutput "and let you choose the restore options yourself."
UserOutput "Keep in mind, that the new root is mounted under '$TARGET_FS_ROOT',"
UserOutput "so use where=$TARGET_FS_ROOT on restore."
UserOutput "The bconsole history contains the preconfigured restore command."
UserOutput ""

bareos_recovery_mode="$( UserInput -I BAREOS_RECOVERY_MODE -p "Choose restore mode: " -D "automatic" "automatic" "manual" )"

if [ "$bareos_recovery_mode" == "manual" ]; then

    #  fill bconsole history
    cat <<EOF >~/.bconsole_history
exit
list jobs client=$BAREOS_CLIENT jobtype=R
list backups client=$BAREOS_CLIENT
status client=$BAREOS_CLIENT
restore client=$BAREOS_CLIENT $FILESET $RESTOREJOB where=$TARGET_FS_ROOT
restore client=$BAREOS_CLIENT $FILESET $RESTOREJOB where=$TARGET_FS_ROOT select all done
EOF

    if bconsole 0<&6 1>&7 2>&8 ; then
        Log "bconsole finished with zero exit code"
    else
        Log "bconsole finished with non-zero exit code $?"
    fi

else
    # bareos_recovery_mode == automatic: restore most recent backup automatically
    
    LogPrint "starting restore using bconsole:"
    LogPrint "$RESTORE_CMD"

    printf "%s\n%s\n" "@tee $TMP_DIR/bconsole-restore.log" "$RESTORE_CMD" | bconsole
    Log "$(cat $TMP_DIR/bconsole-restore.log)"
fi

LogPrint "waiting for restore job"

wait_restore_job "${last_restore_jobid_old}"
local job_exitcode=$?
LogPrint "Restore job ${RESTORE_JOBID} finished."    
if [ ${job_exitcode} -eq 0 ]; then
    LogPrint "Restore job finished successfully."
elif [ ${job_exitcode} -eq 1 ]; then
    LogPrint "WARNING: Restore job finished with warnings."
else
    LogPrint "$(bconsole <<< "list joblog jobid=${RESTORE_JOBID}")"
    Error "Bareos Restore failed (${job_exitcode})"
fi

UserOutput "Please verify that the backup has been restored correctly to '$TARGET_FS_ROOT'"
UserOutput "in the provided shell. When finished, type exit in the shell to continue recovery."
