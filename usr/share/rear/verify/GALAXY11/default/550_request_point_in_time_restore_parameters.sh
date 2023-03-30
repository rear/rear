# Older CommVault used this
# qlist jobhistory -tf commvtoken -c $HOSTNAME -js Completed -jt Backup -dispJobTime
# GALAXY11 seems to use this
# qlist jobhistory -c <rechner> -js Completed -jt Backup -dispJobTime
# JOBID       STATUS       STORAGE POLICY                   APPTYPE              BACKUPSET           SUBCLIENT    INSTANCE     StartTime               EndTime
# -----       ------       --------------                   -------              ---------           ---------    --------     ---------               -------
# 31111315    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/06 19:05:16     2023/03/06 19:06:07
# 31099537    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/05 19:05:18     2023/03/05 19:06:17
# 31088336    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/04 19:05:10     2023/03/04 19:08:29
# 31076891    Completed    SOME_OTHER_CRYPTIC_NAME          Linux File System    defaultBackupSet    default      <default>    2023/03/03 19:30:21     2023/03/03 19:33:25
# 31076703    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/03 19:05:17     2023/03/03 19:08:16
# 31064918    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/02 19:05:11     2023/03/02 19:06:12
# 31052737    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/03/01 19:05:17     2023/03/01 19:06:49
# 31027598    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/02/27 19:05:13     2023/03/01 10:57:46
# 31015949    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/02/26 19:05:16     2023/02/26 19:06:17
# 31004755    Completed    SOME_CRYPTIC_NAME                Linux File System    defaultBackupSet    default      <default>    2023/02/25 19:05:13     2023/02/25 19:06:23
# 30993155    Completed    SOME_OTHER_CRYPTIC_NAME          Linux File System    defaultBackupSet    default      <default>    2023/02/24 19:05:18     2023/02/24 19:07:35
# Ask for point in time to recover with Commvault (BACKUP=GALAXY11).
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
    answer=$( UserInput -I GALAXY11_RESTORE_PIT -r -p "Enter date/time (MM/DD/YYYY HH:mm:ss) or press ENTER" )
    # When the user pressed only ENTER leave this script to restore the most recent available backup:
    if test -z "$answer"; then
        UserOutput "Skipping Commvault Point-In-Time restore, will restore most recent backup."
        GALAXY11_PIT=""
        GALAXY11_ZEIT=""
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
GALAXY11_ZEIT="$answer"
GALAXY11_PIT="QR_RECOVER_POINT_IN_TIME"

UserOutput "Doing Commvault Point-In-Time restore with date and time $GALAXY11_ZEIT"

