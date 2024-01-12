# Ask for point in time to recover with PPDM.

if [[ "$PPDM_RESTORE_PIT" ]]; then
    LogPrint "Using $PPDM_RESTORE_PIT from configuration for point in time restore"
    return
fi

UserOutput "PPDM restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively specify date and optionally time for Point-In-Time restore."
UserOutput "Specifying only a date means to take the last backups from that day."
UserOutput ""

local answer= valid_date_and_time_input= ppdm_restore_pit_date= ppdm_restore_pit_time=

# Let the user enter date and time again and again until the input is valid
# or the user pressed only ENTER to restore the most recent available backup:
while true; do
    answer=$(UserInput -I PPDM_RESTORE_PIT -r -p "Enter date/time (YYYY-MM-DD [HH[:MM[:SS]]]) or press ENTER for latest backup")
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer"; then
        UserOutput "Skipping PPDM Point-In-Time restore, will restore most recent backup."
        PPDM_RESTORE_PIT=$(date +"%Y-%m-%d %T") # set "now" as PIT time if not set
        return
    fi
    # Try to do TSM Point-In-Time restore provided the user input is valid date and time:
    valid_date_and_time_input="yes"
    # Validate date:
    ppdm_restore_pit_date=$(date -d "$answer" +%Y-%m-%d) || valid_date_and_time_input="no"
    # Validate time:
    ppdm_restore_pit_time=$(date -d "$answer" +%T) || valid_date_and_time_input="no"
    # replace time of 00:00:00 with 23:59:59 because a user giving only a date means "any backup from that day"
    [[ "$ppdm_restore_pit_time" == "00:00:00" ]] && ppdm_restore_pit_time="23:59:59"
    # Exit the while loop when the user input is valid date and time:
    is_true $valid_date_and_time_input && break
    # Show the user that his input is invalid and do the the while loop again:
    LogPrintError "Invalid date and/or time '$answer' specified, please try again."
done

PPDM_RESTORE_PIT="$ppdm_restore_pit_date $ppdm_restore_pit_time"
UserOutput "Restoring all PPDM assets from backup before $ppdm_restore_pit_date $ppdm_restore_pit_time (YYYY-MM-DD HH:MM:SS)"
