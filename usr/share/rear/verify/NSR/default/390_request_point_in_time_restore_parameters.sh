# 390_request_point_in_time_restore_parameters.sh
#
# Ask for an EMC NetWorker (Legato) Point-In-Time Restore.
# One point in time is used for all filespaces.
# This causes the recover to use the input date or date/time to be used as the endtime -t option
# see the usr/share/rear/restore/NSR/default/400_restore_with_nsr.sh script.

NSR_ENDTIME=()      
NSR_HAS_PROMPT=0

# Ask for a point-in-time (PIT) recovery date/time just in case 
# NSR_CLIENT_MODE = YES and NSR_CLIENT_REQUESTRESTORE = NO else skip

if is_true "$NSR_CLIENT_MODE"; then
    if is_false "$NSR_CLIENT_REQUESTRESTORE"; then
        UserOutput ""
        UserOutput "EMC NetWorker (Legato) restores by default the latest backup data."
        UserOutput "Press only ENTER to restore the most recent available backup."
        UserOutput "Alternatively specify date (and time) for Point-In-Time Restore."

        local answer=""
        local valid_date_and_time_input=""
        local nsr_endtime_date=""
        local nsr_endtime_time=""

        # Let the user enter date and time again and again until the input is valid
        # or the user pressed only ENTER to restore the most recent available backup:
        while true ; do
            answer=$( UserInput -I NSR_RESTORE_PIT -r -p "Enter date (mm/dd/yyyy) or date and time (mm/dd/yyyy HH:MM:SS) or press ENTER" )
            # When the user pressed only ENTER leave this script to restore the most recent available backup:
            if test -z "$answer" ; then
                UserOutput "Skipping EMC NetWorker (Legato) Point-In-Time Restore, will restore most recent backup."
                return
            fi
            # Try to do EMC NetWorker (Legato) Point-In-Time Restore provided the user input is valid date and time:
            valid_date_and_time_input="yes"
            # Validate date:
            nsr_endtime_date=$( date -d "$answer" +%m/%d/%Y ) || valid_date_and_time_input="no"
            # Validate time:
            nsr_endtime_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
            # Exit the while loop when the user input is valid date and time:
            is_true $valid_date_and_time_input && break
            # Show the user that his input is invalid and do the the while loop again:
            LogPrintError "Invalid date and/or time '$answer' specified."
        done

        # Do EMC NetWorker (Legato) Point-In-Time Restore:
        NSR_ENDTIME=( "$nsr_endtime_date" )
        # When also an actual time was specified (i.e. when it is not "00:00:00") add it:
        test "$nsr_endtime_time" != "00:00:00" && NSR_ENDTIME+=( "$nsr_endtime_time" )

        UserOutput "Doing EMC NetWorker (Legato) Point-In-Time Restore of all filespaces at or before ${NSR_ENDTIME[@]}"
        NSR_HAS_PROMPT=0
    else
        Log "Skipping to request an EMC Networker (Legato) point-in-time restore."
        NSR_HAS_PROMPT=1
    fi
fi