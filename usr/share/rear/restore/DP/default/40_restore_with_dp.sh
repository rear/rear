# 40_restore_with_dp.sh
# Purpose: Restore script to restore file systems with Data Protector

# /opt/omni/bin/omnidb -filesystem test.internal.it3.be:/ '/' -latest -detail
#
#SessionID     : 2008/12/24-1
#	Started            : wo 24 dec 2008 11:42:21 CET
#	Finished           : wo 24 dec 2008 11:54:52 CET
#	Object status      : Completed
#	Object size        : 2043947 KB
#	Backup type        : Full
#	Protection         : Protected for 2 days
#	Catalog retention  : Protected permanently
#	Access             : Private
#	Number of warnings : 3
#	Number of errors   : 0
#	Device name        : DDS4
#	Backup ID          : n/a
#	Copy ID            : 20 (Orig)

# The list of file systems to restore is listed in file $TMP_DIR/list_of_fs_objects
# per line we have something like: test.internal.it3.be:/ '/'

[ -f $TMP_DIR/DP_GUI_RESTORE ] && return # GUI restore explicetely requested

# we will loop over all objects listed in $TMP_DIR/dp_list_of_fs_objects
cat $TMP_DIR/dp_list_of_fs_objects | while read object
do
	host_fs=`echo ${object} | awk '{print $1}'`
	fs=`echo ${object} | awk '{print $1}' | cut -d: -f 2`
	label=`echo "${object}" | cut -d"'" -f 2`
	# only retain the latest backup which was completed successfully
	if grep -q "^${fs} " ${VAR_DIR}/recovery/mountpoint_device; then
		LogPrint "Restore filesystem ${object}"
		SessionID=`cat $TMP_DIR/dp_recovery_session`
		Device=`/opt/omni/bin/omnidb -session ${SessionID} -detail | grep Device | sort -u | tail -n 1 | awk '{print $4}'`
		/opt/omni/bin/omnir -filesystem ${host_fs} "${label}" -full -session ${SessionID} -tree ${fs} -into /mnt/local -sparse -device ${Device} -target `hostname` -log >&8
		case $? in
			0)  Log "Restore of ${fs} was successful." ;;
			10) Log "Restore of ${fs} finished with warnings." ;;
			*)  LogPrint "Restore of ${fs} failed."
				> $TMP_DIR/DP_GUI_RESTORE
				break # get out of the loop
				;;
		esac
	fi # if grep "^${fs}
done
