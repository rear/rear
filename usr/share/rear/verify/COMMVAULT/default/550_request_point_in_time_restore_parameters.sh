# qlist jobhistory -tf commvtoken -c $HOSTNAME -js Completed -jt Backup -dispJobTime
# Ask for point in time to recover with Commvault (BACKUP=COMMVAULT).
# One point in time is used for all filespaces.

UserOutput ""
UserOutput "Commvault restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively specify date and time for Point-In-Time restore."

local answer=""
local valid_date_and_time_input=""
local commvault_restore_pit_date=""
local commvault_restore_pit_time=""

# Let the user enter date and time again and again until the input is valid
# or the user pressed only ENTER to restore the most recent available backup:
while true ; do
    answer=$( UserInput -I COMMVAULT_RESTORE_PIT -r -p "Enter date/time (MM/DD/YYYY HH:mm:ss) or press ENTER" )
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer"; then
        UserOutput "Skipping Commvault Point-In-Time restore, will restore most recent backup."
        COMMVAULT_PIT=""
        COMMVAULT_ZEIT=""
        return
    fi
    # Try to do Commvault Point-In-Time restore provided the user input is valid date and time:
    valid_date_and_time_input="yes"
    # Validate date:
    commvault_restore_pit_date=$( date -d "$answer" +%Y.%m.%d ) || valid_date_and_time_input="no"
    # Validate time:
    commvault_restore_pit_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
    # Exit the while loop when the user input is valid date and time:
    is_true $valid_date_and_time_input && break
    # Show the user that his input is invalid and do the the while loop again:
    LogPrintError "Invalid date and/or time '$answer' specified."
done

# Do Commvault Point-In-Time restore:
COMMVAULT_ZEIT="$answer"
COMMVAULT_PIT="QR_RECOVER_POINT_IN_TIME"

UserOutput "Doing Commvault Point-In-Time restore with date and time $COMMVAULT_ZEIT"

