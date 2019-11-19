
# Ask for point in time to recover with TSM.
# One point in time is used for all filespaces.

UserOutput ""
UserOutput "TSM restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively specify date and time for Point-In-Time restore."

local answer=""
local valid_date_and_time_input=""
local tsm_restore_pit_date=""
local tsm_restore_pit_time=""

# Let the user enter date and time again and again until the input is valid
# or the user pressed only ENTER to restore the most recent available backup:
while true ; do
    answer=$( UserInput -I TSM_RESTORE_PIT -r -p "Enter date/time (YYYY-MM-DD HH:mm:ss) or press ENTER" )
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer"; then
        UserOutput "Skipping TSM Point-In-Time restore, will restore most recent backup."
        return
    fi
    # Try to do TSM Point-In-Time restore provided the user input is valid date and time:
    valid_date_and_time_input="yes"
    # Validate date:
    tsm_restore_pit_date=$( date -d "$answer" +%Y.%m.%d ) || valid_date_and_time_input="no"
    # Validate time:
    tsm_restore_pit_time=$( date -d "$answer" +%T ) || valid_date_and_time_input="no"
    # Exit the while loop when the user input is valid date and time:
    is_true $valid_date_and_time_input && break
    # Show the user that his input is invalid and do the the while loop again:
    LogPrintError "Invalid date and/or time '$answer' specified."
done

# Do TSM Point-In-Time restore:
# Add valid date to dsmc options:
TSM_DSMC_RESTORE_OPTIONS+=( -date=5 -pitd="$tsm_restore_pit_date" )
# Add valid actual time (i.e. when it is not "00:00:00") to dsmc options:
# FIXME: Is it right to add '-date=5' here a second time to the TSM_DSMC_RESTORE_OPTIONS array
# because it was already added above in the "Add valid date to dsmc options" step?
test "$tsm_restore_pit_time" != "00:00:00" && TSM_DSMC_RESTORE_OPTIONS+=( -date=5 -pitt="$tsm_restore_pit_time" )

UserOutput "Restoring all TSM filespaces from backup before $tsm_restore_pit_date $tsm_restore_pit_time (YYYY.MM.DD HH:mm:ss)"
UserOutput "Note: The following list of file spaces always shows the latest backup and not the date/time you specified here."

