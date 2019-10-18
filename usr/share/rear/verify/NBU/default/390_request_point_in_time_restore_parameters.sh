
# Ask for NBU NetBackup Point-In-Time Restore.
# One point in time is used for all filespaces.
# This causes the bprecover to use the input date or date/time to be used as the endtime -e option
# see the usr/share/rear/restore/NBU/default/400_restore_with_nbu.sh script.

NBU_ENDTIME=()

UserOutput ""
UserOutput "NetBackup restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively specify date (and time) for Point-In-Time Restore."

local answer=""
local valid_date_and_time_input=""
local nbu_endtime_date=""
local nbu_endtime_time=""

# Let the user enter date and time again and again until the input is valid
# or the user pressed only ENTER to restore the most recent available backup:
while true ; do
    answer=$( UserInput -I NBU_RESTORE_PIT -r -p "Enter date (mm/dd/yyyy) or date and time (mm/dd/yyyy HH:MM:SS) or press ENTER" )
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer" ; then
        UserOutput "Skipping NetBackup Point-In-Time Restore, will restore most recent backup."
        return
    fi
    # Try to do NetBackup Point-In-Time Restore provided the user input is valid date and time:
    valid_date_and_time_input="yes"
    # Validate date:
    nbu_endtime_date=$( date -d "$answer" +%m/%d/%Y ) || valid_date_and_time_input="no"
    # Validate time:
    nbu_endtime_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
    # Exit the while loop when the user input is valid date and time:
    is_true $valid_date_and_time_input && break
    # Show the user that his input is invalid and do the the while loop again:
    LogPrintError "Invalid date and/or time '$answer' specified."
done

# Do NetBackup Point-In-Time Restore:
NBU_ENDTIME=( "$nbu_endtime_date" )
# When also an actual time was specified (i.e. when it is not "00:00:00") add it:
test "$nbu_endtime_time" != "00:00:00" && NBU_ENDTIME+=( "$nbu_endtime_time" )

UserOutput "Doing NetBackup Point-In-Time Restore of all filespaces at or before ${NBU_ENDTIME[@]}"

