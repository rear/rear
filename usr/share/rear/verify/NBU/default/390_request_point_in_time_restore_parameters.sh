# Ask for point in time to recover with NBU.
# One point in time is used for all filespaces.
# This causes the bprecover to use the input date or date/time to be used as the endtime -e option

NBU_ENDTIME=()

LogPrint ""
LogPrint "Netbackup restores by default the latest backup data. Alternatively you can specify"
LogPrint "a different date and time to enable Point-In-Time Restore. Press ENTER to"
LogPrint "use the most recent available backup"
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -r -p "Enter date (mm/dd/yyyy) or date/time (mm/dd/yyyy HH:MM:SS) or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8

# validate input
if test -z "${REPLY}"; then
        LogPrint "Skipping Point-In-Time Restore, will restore most recent data."
else
        BAD_ENDTIME=0
        # validate date
        NBU_ENDTIME_DATE=$( date -d "$REPLY" +%m/%d/%Y 2>/dev/null ) || BAD_ENDTIME=1
        # validate time
        NBU_ENDTIME_TIME=$( date -d "$REPLY" +%T 2>/dev/null ) || BAD_ENDTIME=1
        [ ${BAD_ENDTIME} -ne 1 ]
        BugIfError "Incorrect date and/or time definition used: ${REPLY} Ending NetBackup Restore Attempt..."
        if test "$NBU_ENDTIME_TIME" = "00:00:00"; then
            NBU_ENDTIME=( "${NBU_ENDTIME_DATE}" )
        else
            NBU_ENDTIME=( "${NBU_ENDTIME_DATE}" "${NBU_ENDTIME_TIME}" )
        fi

        LogPrint "Restoring all filespaces from backup at or before ${NBU_ENDTIME[@]}"
fi
