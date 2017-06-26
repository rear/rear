# Ask for point in time to recover with TSM.
# One point in time is used for all filespaces.

LogPrint ""
LogPrint "TSM restores by default the latest backup data. Alternatively you can specify"
LogPrint "a different date and time to enable Point-In-Time Restore. Press ENTER to"
LogPrint "use the most recent available backup"
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -r -p "Enter date/time (YYYY-MM-DD HH:mm:ss) or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
# validate input
if test -z "${REPLY}"; then
    LogPrint "Skipping Point-In-Time Restore, will restore most recent data."
else
    # validate date
    TSM_RESTORE_PIT_DATE=$( date -d "$REPLY" +%Y.%m.%d 2>/dev/null ) ||\
    Error "Invalid date for recovery: '$REPLY'"
    # correct date, add to dsmc options
    TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitd="$TSM_RESTORE_PIT_DATE" )

    # validate time
    TSM_RESTORE_PIT_TIME=$( date -d "$REPLY" +%T 2>/dev/null ) ||\
    Error "Invalid time for recovery: '$REPLY'"
    if test "$TSM_RESTORE_PIT_TIME" = "00:00:00" ; then
        # invalid / missing time, do nothing
        TSM_RESTORE_PIT_TIME=
    else
        # valid time, add to dsmc options
        TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitt="$TSM_RESTORE_PIT_TIME" )
    fi
    LogPrint "Restoring all filespaces from backup before ${TSM_RESTORE_PIT_DATE} ${TSM_RESTORE_PIT_TIME} (MM/DD/YYYY HH:mm:ss)"
    LogPrint "Please note that the following list of file spaces always shows the latest backup"
    LogPrint "and not the date/time you specified here."
fi

