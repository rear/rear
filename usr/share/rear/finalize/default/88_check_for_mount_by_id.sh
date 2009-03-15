#
# mounting via /dev/disk/by-id is currently not supported for automated disaster recovery
#
# the reason is the fact that we do not know how to set the original LUN IDs to the new / recovered hardware.
#
# to help the user we check for this situation and print out a current list of LUN IDs
#
if grep -q by-id $VAR_DIR/recovery/fstab ; then
	LogPrint ""
	LogPrint "WARNING ! You are mounting some devices by ID. Please be aware that the IDs"
	LogPrint "are hardware dependant and that you might have to adjust your fstab to match"
	LogPrint "the new IDs. Currently your system has the following disks with LUN IDs:"
	while read major minor size device ; do
		sysfs="$(tr / \! <<<"$device")"
		ID_SERIAL=
		eval "$(scsi_id -g -x -n -s /block/"$sysfs" -d /dev/$device)"
		if test "$ID_SERIAL" ; then
			LogPrint "  $ID_SERIAL  /dev/$device  $((size/1024))MB"
		fi
	done </proc/partitions
	LogPrint ""
fi
