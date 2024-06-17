# 550_check_bareos_restore_jobs.sh

# Let the user select a matching Bareos Restore Job.
# Alternatively, BAREOS_RESTORE_JOB can be set in the config file.

mapfile -t restore_jobs < <( get_available_restore_job_names )

LogPrint "available restore jobs:" "${restore_jobs[@]}"

if (( ${#restore_jobs[@]} == 0 )); then
    Error "No Bareos restore jobs found"
fi

if [ "$BAREOS_RESTORE_JOB" ]; then
    LogPrint "BAREOS_RESTORE_JOB=$BAREOS_RESTORE_JOB"
    if ! IsInArray "$BAREOS_RESTORE_JOB" "${restore_jobs[@]}"; then
        Error "Bareos Restore Job ($BAREOS_RESTORE_JOB) is not available. Available restore jobs:" "${restore_jobs[@]}"
    fi
    return
fi

if (( ${#restore_jobs[@]} == 1 )); then
    BAREOS_RESTORE_JOB="${restore_jobs[0]}"
    {
        echo "# added by prep/BAREOS/default/550_check_bareos_restore_jobs.sh"
        echo "BAREOS_RESTORE_JOB=$BAREOS_RESTORE_JOB"
        echo
    } >> "$ROOTFS_DIR/etc/rear/rescue.conf"
    return
fi

Error "Could not determine which restore job to use. Please configure it using BAREOS_RESTORE_JOB in $CONFIG_DIR/local.conf"
