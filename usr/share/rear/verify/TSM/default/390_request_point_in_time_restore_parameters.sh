# Ask for point in time to recover with TSM.
# One point in time is used for all filespaces.

LogPrint ""
LogPrint "TSM restores by default the latest backup data. Alternatively you can specify"
LogPrint "a different date and time to enable Point-In-Time Restore. Press ENTER to"
LogPrint "use the most recent available backup"

answer=$(UserInput -I TSM_RESTORE_PIT -t $WAIT_SECS -r -p "Enter date/time (YYYY-MM-DD HH:mm:ss) or press ENTER")
if test -z "${answer}"; then
    LogPrint "Skipping Point-In-Time Restore, will restore most recent data."
else
    # validate date
    tsm_restore_pit_date=$( date -d "$answer" +%Y.%m.%d 2>/dev/null ) ||\
    Error "Invalid date for recovery: '$answer'"
    # correct date, add to dsmc options
    TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitd="$tsm_restore_pit_date" )

    # validate time
    tsm_restore_pit_time=$( date -d "$answer" +%T 2>/dev/null ) ||\
    Error "Invalid time for recovery: '$answer'"
    if test "$tsm_restore_pit_time" != "00:00:00" ; then
        # valid time, add to dsmc options
        TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitt="$tsm_restore_pit_time" )
    fi
    LogPrint "Restoring all filespaces from backup before ${tsm_restore_pit_date} ${tsm_restore_pit_time} (MM/DD/YYYY HH:mm:ss)"
    LogPrint "Please note that the following list of file spaces always shows the latest backup"
    LogPrint "and not the date/time you specified here."
fi

unset answer tsm_restore_pit_date tsm_restore_pit_time