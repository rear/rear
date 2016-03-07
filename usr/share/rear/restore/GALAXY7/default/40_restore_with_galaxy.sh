#
# restore data with Galaxy
#

# verify that we have a backupset
[ "$GALAXY7_BACKUPSET" ]
StopIfError "Galaxy Backup Set not defined [GALAXY7_BACKUPSET=]."

# create argument file
cat <<EOF >$TMP_DIR/galaxy.restore.options
$(test -r "$GALAXY7_Q_ARGUMENTFILE" && cat "$GALAXY7_Q_ARGUMENTFILE")
[sourceclient]
$HOSTNAME
[level]
1
[options]
QR_PRESERVE_LEVEL
QR_DO_NOT_OVERWRITE_FILE_ON_DISK
[dataagent]
Q_LINUX_FS
[backupset]
$GALAXY7_BACKUPSET
[sourcepaths]
/
[destinationpath]
$TARGET_FS_ROOT
EOF

# initialize variable
jobstatus=Unknown

if jobid=$(qoperation restore -af $TMP_DIR/galaxy.restore.options) ; then
	jobid=${jobid// /}	# remove trailing blanks
	LogPrint "Restoring data with Galaxy (job $jobid)"
	while true ; do
		# output of qlist job -co s -j ## :
		# STATUS
		# ------
		# Pending
		# the array gets rid of the line breaks :-)

		jobdetails=( $(qlist job -co s -j $jobid) )
		StopIfError "Could not receive job details. Check log file."

		jobstatus="${jobdetails[2]}"

		# stop waiting if the job reached a final status
		case "$jobstatus" in
			?omplet*)
				echo
				LogPrint "Restore completed successfully."
				break
				;;
			?uspend*|*end*|?unn*)
				printf "\r%-79s" "$(date +"%Y-%m-%d %H:%M:%S") job is $jobstatus"
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
	Error "Could not start Galaxy restore job. Check log file."
fi

# create missing directories
pushd $TARGET_FS_ROOT >&8
for dir in opt/galaxy/Base/Temp opt/galaxy/Updates opt/galaxy/iDataAgent/jobResults ; do
	mkdir -p "$dir"
done
popd >&8
