
# Ask for point in time to recover with TSM.
# One point in time is used for all filespaces.

LogPrint ""
LogPrint "TSM restores by default the latest backup data."
LogPrint "Press ENTER to restore the most recent available backup."
LogPrint "Alternatively specify date and time for Point-In-Time restore."

local answer=""

answer=$( UserInput -I TSM_RESTORE_PIT -t $WAIT_SECS -r -p "Enter date/time (YYYY-MM-DD HH:mm:ss) or press ENTER" )

if test -z "$answer"; then
    LogPrint "Skipping TSM Point-In-Time restore, will restore most recent backup."
    return
fi

local tsm_restore_pit_date=""
local tsm_restore_pit_time=""

# Validate date:
tsm_restore_pit_date=$( date -d "$answer" +%Y.%m.%d ) || Error "Invalid date specified for TSM recovery: '$answer'"
# Add valid date to dsmc options:
TSM_DSMC_RESTORE_OPTIONS+=( -date=5 -pitd="$tsm_restore_pit_date" )

# Validate time:
tsm_restore_pit_time=$( date -d "$answer" +%T ) || Error "Invalid time specified for TSM recovery: '$answer'"
# Add valid actual time (i.e. when it is not "00:00:00") to dsmc options:
# FIXME: Is it right to add '-date=5' here a second time to the TSM_DSMC_RESTORE_OPTIONS array
# because it was already added above in the "Add valid date to dsmc options" step?
test "$tsm_restore_pit_time" != "00:00:00" && TSM_DSMC_RESTORE_OPTIONS+=( -date=5 -pitt="$tsm_restore_pit_time" )

LogPrint "Restoring all TSM filespaces from backup before $tsm_restore_pit_date $tsm_restore_pit_time (MM/DD/YYYY HH:mm:ss)"
LogPrint "Note: The following list of file spaces always shows the latest backup and not the date/time you specified here."

