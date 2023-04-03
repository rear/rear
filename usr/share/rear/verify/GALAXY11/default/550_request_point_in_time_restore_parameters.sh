
# qlist jobhistory -c $HOSTNAME -js Completed -jt Backup -dispJobTime -b defaultBackupSet -a Q_LINUX_FS
# JOBID       STATUS       STORAGE POLICY                   SUBCLIENT    INSTANCE     StartTime               EndTime                 
# -----       ------       --------------                   ---------    --------     ---------               -------                 
# 31439021    Completed    RZ1_RZ2_BB14_DD_FS_028d_NoAux    default      <default>    2023/04/02 17:30:09     2023/04/02 17:31:09     
# 31427228    Completed    RZ1_RZ2_BB14_DD_FS_028d_NoAux    default      <default>    2023/04/01 17:30:16     2023/04/01 17:30:55     
# 31415158    Completed    RZ1_RZ2_BB14_DD_FS_028d_NoAux    default      <default>    2023/03/31 17:30:10     2023/03/31 17:31:15     
# 31411972    Completed    RZ1_RZ2_BB14_DD_FS_112d_NoAux    default      <default>    2023/03/31 07:01:13     2023/03/31 07:03:31     
# 31212435    Completed    RZ1_RZ2_BB14_DD_FS_112d_NoAux    default      <default>    2023/03/14 23:00:14     2023/03/14 23:03:50     
# 31194138    Completed    RZ1_RZ2_BB14_DD_FS_028d_NoAux    default      <default>    2023/03/13 17:30:09     2023/03/13 17:31:25

# Ask for point in time to recover with Commvault (BACKUP=GALAXY11).
# One point in time is used for all filespaces.

local commvault_jobhistory="$(qlist jobhistory -c $HOSTNAME -js Completed -jt Backup -dispJobTime -b "$GALAXY11_BACKUPSET" -a Q_LINUX_FS)"

UserOutput ""
UserOutput "Commvault restores by default the latest backup data."
UserOutput "Press only ENTER to restore the most recent available backup."
UserOutput "Alternatively select one of the backups to restore"
UserOutput ""
UserOutput "$commvault_jobhistory"

local job_end_times=()
while IFS="|" read job_id job_status job_storage_policy job_subclient job_instance job_start_time job_end_time junk ; do
    job_end_times+=( "$job_end_time" )
done < <(sed -E -e '1,2d' -e 's/  +/|/g' <<<"$commvault_jobhistory")

until IsInArray "$GALAXY11_PIT_RECOVERY" "${job_end_times[@]}"; do
	GALAXY11_PIT_RECOVERY=$( UserInput -I GALAXY11_PIT_RECOVERY -p "Select point-in-time restore to use (ENTER for latest):" "${job_end_times[@]}" )
done

if test "$GALAXY11_PIT_RECOVERY" ; then
    UserOutput "Doing Commvault Point-In-Time restore with date and time $GALAXY11_PIT_RECOVERY"
else
    UserOutput "Doing Commvault latest backup restore"
fi


