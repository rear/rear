
# Ask for NBU NetBackup Point-In-Time Restore.
# One point in time is used for all filespaces.
# This causes the bprecover to use the input date or date/time to be used as the endtime -e option
# see the usr/share/rear/restore/NBU/default/400_restore_with_nbu.sh script.

NBU_ENDTIME=()

LogPrint ""
LogPrint "NetBackup restores by default the latest backup data."
LogPrint "Press ENTER to restore the most recent available backup."
LogPrint "Alternatively specify date (and time) for Point-In-Time Restore."

local answer=""
answer=$( UserInput -I NBU_RESTORE_PIT -t $WAIT_SECS -r -p "Enter date (mm/dd/yyyy) or date and time (mm/dd/yyyy HH:MM:SS) or press ENTER" )

if test -z "$answer"; then
    LogPrint "Skipping NetBackup Point-In-Time Restore, will restore most recent backup."
    return
fi

# Validate user date and time input:
local valid_date_and_time_input="yes"
local nbu_endtime_date=""
local nbu_endtime_time=""
# Validate date:
nbu_endtime_date=$( date -d "$answer" +%m/%d/%Y ) || valid_date_and_time_input="no"
# Validate time:
nbu_endtime_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
# It is an Error (not a BugError) when user input is invalid:
is_true $valid_date_and_time_input || Error "Invalid date and/or time '$answer' specified. Ending NetBackup Restore attempt..."

NBU_ENDTIME=( "$nbu_endtime_date" )
# When also an actual time was specified (i.e. when it is not "00:00:00") add it:
test "$nbu_endtime_time" != "00:00:00" && NBU_ENDTIME+=( "$nbu_endtime_time" )

LogPrint "Doing NetBackup Point-In-Time Restore of all filespaces at or before ${NBU_ENDTIME[@]}"

