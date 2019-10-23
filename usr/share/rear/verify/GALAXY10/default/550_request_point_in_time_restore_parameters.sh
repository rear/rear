
# Ask for point in time to recover with Galaxy 10 (BACKUP=GALAXY10).
# One point in time is used for all filespaces.

UserOutput ""
UserOutput "Galaxy 10 restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively specify date and time for Point-In-Time restore."

local answer=""
local valid_date_and_time_input=""
local galaxy10_restore_pit_date=""
local galaxy10_restore_pit_time=""

# Let the user enter date and time again and again until the input is valid
# or the user pressed only ENTER to restore the most recent available backup:
while true ; do
    answer=$( UserInput -I GALAXY10_RESTORE_PIT -r -p "Enter date/time (MM/DD/YYYY HH:mm:ss) or press ENTER" )
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer"; then
        UserOutput "Skipping Galaxy 10 Point-In-Time restore, will restore most recent backup."
        GALAXY10_PIT=""
        GALAXY10_ZEIT=""
        return
    fi
    # Try to do Galaxy 10 Point-In-Time restore provided the user input is valid date and time:
    valid_date_and_time_input="yes"
    # Validate date:
    galaxy10_restore_pit_date=$( date -d "$answer" +%Y.%m.%d ) || valid_date_and_time_input="no"
    # Validate time:
    galaxy10_restore_pit_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
    # Exit the while loop when the user input is valid date and time:
    is_true $valid_date_and_time_input && break
    # Show the user that his input is invalid and do the the while loop again:
    LogPrintError "Invalid date and/or time '$answer' specified."
done

# Do Galaxy 10 Point-In-Time restore:
GALAXY10_ZEIT="$answer"
GALAXY10_PIT="QR_RECOVER_POINT_IN_TIME"

UserOutput "Doing Galaxy 10 Point-In-Time restore with date and time $GALAXY10_ZEIT"

