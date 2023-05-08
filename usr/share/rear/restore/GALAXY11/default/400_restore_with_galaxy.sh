#
# restore data with Commvault
#

# verify that we have a backupset
test "$GALAXY11_BACKUPSET" || Error "Commvault Backup Set not defined [GALAXY11_BACKUPSET=]."

# create argument file

cat <<EOF >$TMP_DIR/commvault.restore.options
$(
    test -r "$GALAXY11_Q_ARGUMENTFILE" && cat "$GALAXY11_Q_ARGUMENTFILE"
)
[sourceclient]
$HOSTNAME
[level]
1
[options]
QR_PRESERVE_LEVEL
QR_DO_NOT_OVERWRITE_FILE_ON_DISK
$(  
    test "$GALAXY11_PIT_RECOVERY" && echo QR_RECOVER_POINT_IN_TIME
)
[dataagent]
Q_LINUX_FS
[backupset]
$GALAXY11_BACKUPSET
[sourcepaths]
/
[destinationpath]
$TARGET_FS_ROOT
$(
    test "$GALAXY11_PIT_RECOVERY" && echo -e "[browseto]\n$GALAXY11_PIT_RECOVERY"
)
EOF

Log "Restoring from CommVault with the following restore options:"
Log "$(cat $TMP_DIR/commvault.restore.options)"

local jobstatus=Unknown jobstatus_output prevstatus jobid job_errors

jobid=$(qoperation restore -af $TMP_DIR/commvault.restore.options) || \
    Error "Could not start Commvault restore job. Check log file."

jobid=${jobid// /} # remove trailing blanks
prevstatus=

LogPrint "Restoring data with Commvault (job $jobid)"

sleep 10 # wait for job to be created

while true; do
    # every 60 seconds, first check for an error condition on our job and
    # then check for the current status of the job

    # qlist job -j 31900347 -co sr
    # STATUS    FAILURE REASON          
    # ------    --------------          
    # Killed    318767965, 402653226    

    # Messages for Job failure/pending reasons:
    # 31900347	318767965 -> Killed by svc_ansible_commvault_test. Reason:[].
    # 	402653226 -> Cannot start restore program on host [FQDN*HOST*8400*8402] - a network error occurred or the product's services are not running.

    jobstatus_output=$(qlist job -j $jobid -co sr) || Error "Could not get job status output."
    jobstatus=$(sed -n 3p <<<"$jobstatus_output")
    read -r job_status_name job_errors <<<"$jobstatus"

    if contains_visible_char "$job_errors"; then
        Log "$jobstatus_output"
        # kill problematic job to clean up resources on backup server
        qoperation jobcontrol -o kill -j $jobid && Log "Job $jobid was successfully killed."
        echo
        Error "Job $jobid has status $job_status_name with errors. Check log file."
    fi

    # stop waiting if the job reached a final status
    case "$job_status_name" in
    (?omplet*)
        echo
        LogPrint "Restore completed successfully."
        break
        ;;
    (?uspend* | *end* | ?unn* | ?ait*)
        ProgressInfo "$(date +"%Y-%m-%d %H:%M:%S") job is $jobstatus"
        [ "$jobstatus" != "$prevstatus" ] && Log "$jobstatus"
        prevstatus="$jobstatus"
        ;;
    (?ail* | ?ill*)
        echo
        Error "Restore job failed or was killed, aborting recovery."
        ;;
    (*)
        echo
        LogPrint "$jobstatus_output"
        Error "Restore job has an unknown state [$job_status_name], aborting."
        ;;
    esac

    sleep 60

done


for dir in "$TARGET_FS_ROOT/$GALAXY11_TEMP_DIRECTORY" "$TARGET_FS_ROOT/$GALAXY11_CORE_DIRECTORY"/Updates "$TARGET_FS_ROOT/$GALAXY11_JOBS_RESULTS_DIRECTORY"; do
    mkdir -p $v "$dir"
done