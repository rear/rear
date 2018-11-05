
# Ask for point in time to recover with TSM.
# One point in time is used for all filespaces.

test "none" = "$TSM_RESTORE_PIT_DATE" && return

# When TSM_RESTORE_PIT_DATE is specified convert its date format and validate it:
if test "$TSM_RESTORE_PIT_DATE" ; then
    if ! TSM_RESTORE_PIT_DATE=$( date -d "$TSM_RESTORE_PIT_DATE" +%Y.%m.%d ) ; then
        LogPrintError "Invalid TSM_RESTORE_PIT_DATE '$TSM_RESTORE_PIT_DATE'"
        TSM_RESTORE_PIT_DATE=""
    fi
fi

# When TSM_RESTORE_PIT_TIME is specified validate it:
if test "$TSM_RESTORE_PIT_TIME" ; then
    if ! TSM_RESTORE_PIT_TIME=$( date -d "$TSM_RESTORE_PIT_TIME" +%T ) ; then
        LogPrintError "Invalid TSM_RESTORE_PIT_TIME '$TSM_RESTORE_PIT_TIME'"
        TSM_RESTORE_PIT_TIME=""
    fi
fi

# When TSM_RESTORE_PIT_DATE or TSM_RESTORE_PIT_TIME is not specified,
# ask the user for it (if needed again and again until date and time are valid):
while test -z "$TSM_RESTORE_PIT_DATE" -o -z "$TSM_RESTORE_PIT_TIME" ; do
    LogPrint "TSM restores by default the latest backup data. Alternatively you can specify"
    LogPrint "a different date and time to enable Point-In-Time Restore."
    LogPrint "Press ENTER to use the most recent available backup."
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -t $WAIT_SECS -r -p "Enter date/time (YYYY-MM-DD HH:mm:ss) or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    if test -z "${REPLY}"; then
        LogPrint "Skipping Point-In-Time Restore, will restore most recent data."
        return
    fi
    # Validate user input date:
    if ! TSM_RESTORE_PIT_DATE=$( date -d "$REPLY" +%Y.%m.%d ) ; then
        LogPrintError "Invalid date: '$REPLY'"
        TSM_RESTORE_PIT_DATE=""
    fi
    # Validate user input time:
    if ! TSM_RESTORE_PIT_TIME=$( date -d "$REPLY" +%T ) ; then
        LogPrintError "Invalid time: '$REPLY'"
        TSM_RESTORE_PIT_TIME=""
    fi
done

# Add valid date to dsmc options:
TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitd="$TSM_RESTORE_PIT_DATE" )

# Only add a meaningful time (i.e. a time that is not "00:00:00") to dsmc options:
if test "$TSM_RESTORE_PIT_TIME" = "00:00:00" ; then
    LogPrint "Restoring all filespaces from backup before $TSM_RESTORE_PIT_DATE (YYYY.MM.DD)"
else
    TSM_DSMC_RESTORE_OPTIONS=( "${TSM_DSMC_RESTORE_OPTIONS[@]}" -date=5 -pitt="$TSM_RESTORE_PIT_TIME" )
    LogPrint "Restoring all filespaces from backup before $TSM_RESTORE_PIT_DATE $TSM_RESTORE_PIT_TIME (YYYY.MM.DD HH:mm:ss)"
fi

LogPrint "Note that the following list of file spaces always shows the latest backup"
LogPrint "and not the Point-In-Time Restore date/time specified here."

