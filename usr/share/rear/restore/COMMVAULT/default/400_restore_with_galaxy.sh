#
# restore data with Commvault
#

# verify that we have a backupset
[ "$COMMVAULT_BACKUPSET" ]
StopIfError "Commvault  Backup Set not defined [COMMVAULT_BACKUPSET=]."

# create argument file

cat <<EOF >$TMP_DIR/commvault.restore.options
$(test -r "$COMMVAULT_Q_ARGUMENTFILE" && cat "$COMMVAULT_Q_ARGUMENTFILE")
[sourceclient]
$HOSTNAME
[level]
1
[options]
QR_PRESERVE_LEVEL
QR_DO_NOT_OVERWRITE_FILE_ON_DISK
$COMMVAULT_PIT
[dataagent]
Q_LINUX_FS
[backupset]
$COMMVAULT_BACKUPSET
[sourcepaths]
/
[destinationpath]
$TARGET_FS_ROOT
EOF

if [ "x$COMMVAULT_ZEIT" != "x" ]; then
cat <<EOF >>$TMP_DIR/commvault.restore.options
[browseto]
$COMMVAULT_ZEIT
EOF
fi

# initialize variable
jobstatus=Unknown

if jobid=$(qoperation restore -af $TMP_DIR/commvault.restore.options) ; then
	jobid=${jobid// /}	# remove trailing blanks
    prevstatus=

	LogPrint "Restoring data with Commvault (job $jobid)"

	while true
    do
		# output of qlist job -co sc -j ## :

        # STATUS     COMPLETE PERCENTAGE
        # ------     -------------------
        # Running    5

        jobstatus=$(/opt/commvault/Base/qlist job -j $job -co sc -tf qsession | tail -n 1)
		StopIfError "Could not receive job details. Check log file."

		# stop waiting if the job reached a final status
		case "$jobstatus" in
			?omplet*)
				echo
				LogPrint "Restore completed successfully."
				break
				;;
			?uspend*|*end*|?unn*|?ait*)
				printf "\r%-79s" "$(date +"%Y-%m-%d %H:%M:%S") job is $jobstatus"
                [ "$jobstatus" != "$prevstatus" ] && LogPrint $jobstatus
                prevstatus="$jobstatus"
				;;
			?ail*|?ill*)
				echo
				Error "Restore job failed or was killed, aborting recovery."
				;;
			*)
				echo
				Error "Restore job has an unknown state [$jobstatus], aborting."
				;;
		esac
		sleep 10
	done

else
	Error "Could not start Commvault restore job. Check log file."
fi

# create missing directories
pushd $TARGET_FS_ROOT >/dev/null
for dir in opt/commvault/Base/Temp opt/commvault/Updates opt/commvault/iDataAgent/jobResults ; do
	mkdir -p "$dir"
done
popd >/dev/null
