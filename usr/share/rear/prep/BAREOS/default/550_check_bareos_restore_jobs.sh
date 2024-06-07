# 550_check_bareos_restore_jobs.sh

[[ ! -z "$BAREOS_RESTORE_JOB" ]] && return   # variable filled in already (via local.conf?)

# echo "show jobs" | bconsole | grep "Name =" | grep restore | grep $HOSTNAME | cut -d= -f2
# "client-restore"
# "client-restore-mysql"

# if we have more then 1 restore job for a client
# then we need to define an extra BAREOS_RESTORE_JOB variable
# containing the name of the restore job to restore the full backup.
# We need this as an argument in the restore workflow.

# Save the found restore job names in a file
echo ".jobs" | bconsole | grep restore | grep $HOSTNAME > "$TMP_DIR/bareos_restorejobs"

# A vanila Bareos setup has exactly ONE restore job for ALL clients.
# If there is no client specific restore job found, then use the default restore job
[ -s "$TMP_DIR/bareos_restorejobs" ] || echo ".jobs" | bconsole | grep -i restore > "$TMP_DIR/bareos_restorejobs"

# when amount of lines > 1 in file $TMP_DIR/bareos_restorejobs
# then we may decide that there is more then 1 restore job
# for current host.

# The wc output is stored in an artificial bash array
# so that $nr_of_restore_jobs can be simply used to get the first word
nr_of_restore_jobs=( $(wc -l $TMP_DIR/bareos_restorejobs) ) 

case "$nr_of_restore_jobs" in
    0 ) Error "No restore job defined in Bareos for $HOSTNAME"
        ;;
    1 ) BAREOS_RESTORE_JOB="$(cat $TMP_DIR/bareos_restorejobs)"
        Log "We found Bareos restore job : $BAREOS_RESTORE_JOB"
        echo "BAREOS_RESTORE_JOB=$BAREOS_RESTORE_JOB" >> $VAR_DIR/bareos.conf
        ;;
    * ) LogPrint "We found several defined Bareos restore jobs :"
        LogPrint "$( cat $TMP_DIR/bareos_restorejobs | sed -e 's/"//g' )"
        Error "Define variable BAREOS_RESTORE_JOB in $CONFIG_DIR/local.conf"
        ;;
esac
