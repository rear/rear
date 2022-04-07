# upstream.log and upstream.rpt on the ReaR system contain valuable 
# information about the disaster recovery, so we archive *.log and *.rpt
# to the restored system.

PREFIX="rear_$( date +%F_%T_%N )"
SERVICENAME=( $(ps -ef | grep uscmd1 | grep servicename | grep -Po 'servicename=\K[^"]+') )
REARLOGPATH="$FDRUPSTREAM_DATA_PATH/rear/logs"

# If SERVICENAME is empty, then FDR/Upstream is not running and we won't 
# be able to find the log files.
if [[ ! "${SERVICENAME[*]}" ]]; then 
	echo
	LogPrintError "***************"
	LogPrintError "***************"
	LogPrintError "No FDR/Upstream services were detected.  Unable to automatically copy logs and reports to the recovered system."
	LogPrintError "Before rebooting, copy any necessary logs and reports from $FDRUPSTREAM_DATA_PATH into the $TARGET_FS_ROOT file tree."
	LogPrintError "***************"
	LogPrintError "***************"
	echo
	Error exit 1
fi


if [[ ! -d $TARGET_FS_ROOT/$REARLOGPATH ]]; then
	mkdir -p $TARGET_FS_ROOT/$REARLOGPATH
fi

echo

countmax=100
count=0
# We need to identify all the running FDR/Upstream services, so we
# can put their logs in the correct directory on the rescued system.
for dir in "${SERVICENAME[@]}"; do
	count=$count+1
	LIVELOGPATH="$FDRUPSTREAM_DATA_PATH/$dir/logs"
	for file in $LIVELOGPATH/*.log $LIVELOGPATH/*.rpt; do
	    LogPrint "Archiving "$( basename "$file" )" to the restored system as:"
	    LogPrint "  $REARLOGPATH/$PREFIX.$( basename "$file" )"
	    cp "$file" "$TARGET_FS_ROOT/$REARLOGPATH/$PREFIX.$( basename "$file" )"
	    LogPrintIfError "Error archiving $file.  Before rebooting, be sure to copy logs and/or reports from $FDRUPSTREAM_DATA_PATH into the $TARGET_FS_ROOT file tree."
	    echo
	done
	# Normally there is only a single FDR/Upstream service, but sometimes
	# users have reason to run two or more services.  If service detection
	# goes wrong, we risk having an infinite loop.  To avoid that we break
	# out of the loop if we detect too many services, using the $countmax
	# variable.
	if (( $count >= $countmax )); then
		echo
		LogPrintError "***************"
		LogPrintError "***************"
		LogPrintError "Number of detected FDR/Upstream services has reached $countmax, which is not normal.  Before rebooting, copy any necessary logs and reports from $FDRUPSTREAM_DATA_PATH into the $TARGET_FS_ROOT file tree."
		LogPrintError "***************"
		LogPrintError "***************"
		echo
		break
	fi
done
