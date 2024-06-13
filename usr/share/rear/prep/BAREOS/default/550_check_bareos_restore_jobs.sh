# 550_check_bareos_restore_jobs.sh

# Let the user select a matching Bareos Restore Job.
# Alternatively, BAREOS_RESTORE_JOB can be set in the config file.

mapfile -t restore_jobs < <( get_available_restore_job_names )

LogPrint "available restore jobs:" "${restore_jobs[@]}"

if (( ${#restore_jobs[@]} == 0 )); then
    Error "No Bareos restore job found"
fi

if [ "$BAREOS_RESTORE_JOB" ]; then
    LogPrint "BAREOS_RESTORE_JOB=$BAREOS_RESTORE_JOB"
    if ! IsInArray "$BAREOS_RESTORE_JOB" "${restore_jobs[@]}"; then
        Error "Bareos Restore Job ($BAREOS_RESTORE_JOB) is not available. Available restore jobs:" "${restore_jobs[@]}"
    fi
    return
fi

local userinput_default
if (( ${#restore_jobs[@]} == 1 )); then
    userinput_default="-D ${restore_jobs[0]}"
fi

until IsInArray "$BAREOS_RESTORE_JOB" "${restore_jobs[@]}" ; do
    BAREOS_RESTORE_JOB="$( UserInput -I BAREOS_RESTORE_JOB $userinput_default -p "Choose Bareos restore jobs: " "${restore_jobs[@]}" )"
done
echo "BAREOS_RESTORE_JOB=$BAREOS_RESTORE_JOB" >> "$VAR_DIR/bareos.conf"
