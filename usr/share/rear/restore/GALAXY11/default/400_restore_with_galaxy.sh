#
# restore data with Commvault
#

# verify that we have a backupset
test "$GALAXY11_BACKUPSET" || Error "Commvault Backup Set not defined [GALAXY11_BACKUPSET=]."

# create argument file

cat <<EOF >$TMP_DIR/commvault.restore.options
$(test -r "$GALAXY11_Q_ARGUMENTFILE" && cat "$GALAXY11_Q_ARGUMENTFILE")
[sourceclient]
$HOSTNAME
[level]
1
[options]
QR_PRESERVE_LEVEL
QR_DO_NOT_OVERWRITE_FILE_ON_DISK
$GALAXY11_PIT
[dataagent]
Q_LINUX_FS
[backupset]
$GALAXY11_BACKUPSET
[sourcepaths]
/
[destinationpath]
$TARGET_FS_ROOT
EOF

if [ "x$GALAXY11_ZEIT" != "x" ]; then
	cat <<EOF >>$TMP_DIR/commvault.restore.options
[browseto]
$GALAXY11_ZEIT
EOF
fi

local jobstatus=Unknown

if jobid=$(qoperation restore -af $TMP_DIR/commvault.restore.options); then
	jobid=${jobid// /} # remove trailing blanks
	prevstatus=

	LogPrint "Restoring data with Commvault (job $jobid)"

	while true; do
		sleep 60
		# output of qlist job -co sc -j ## :

		# STATUS     COMPLETE PERCENTAGE
		# ------     -------------------
		# Running
		jobstatus=$(qlist job -j $jobid -co sc | tail -n 1)

		# stop waiting if the job reached a final status
		case "$jobstatus" in
		?omplet*)
			echo
			LogPrint "Restore completed successfully."
			break
			;;
		?uspend* | *end* | ?unn* | ?ait*)
			printf "\r%-79s" "$(date +"%Y-%m-%d %H:%M:%S") job is $jobstatus"
			[ "$jobstatus" != "$prevstatus" ] && LogPrint $jobstatus
			prevstatus="$jobstatus"
			;;
		?ail* | ?ill*)
			echo
			Error "Restore job failed or was killed, aborting recovery."
			;;
		*)
			echo
			Error "Restore job has an unknown state [$jobstatus], aborting."
			;;
		esac
	done

else
	Error "Could not start Commvault restore job. Check log file."
fi

# create missing directories in recovered system
pushd $TARGET_FS_ROOT >/dev/null
for dir in opt/commvault/Base64/Temp opt/commvault/Updates opt/commvault/iDataAgent/jobResults; do
	mkdir -p "$dir"
done
popd >/dev/null
