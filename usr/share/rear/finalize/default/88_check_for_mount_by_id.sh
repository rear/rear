#
# mounting via /dev/disk/by-id is currently not supported for automated disaster recovery
#
# the reason is the fact that we do not know how to set the original LUN IDs to the new / recovered hardware.
#
# to help the user we check for this situation and print out a current list of LUN IDs
#
# Note: we ignore swap here because we treat it specially somewhere else!
if [ -e /mnt/local/etc/fstab ] && grep -v swap /mnt/local/etc/fstab | grep -q by-id ; then
	LogPrint ""
	LogPrint "WARNING ! You are mounting some devices by ID. Please be aware that the IDs"
	LogPrint "are hardware dependant and that you might have to adjust your fstab to match"
	LogPrint "the new IDs. Currently your system has the following disks with LUN IDs:"
	SCSI_ID_HAVE_RESULT=
	while read major minor size device ; do
		sysfs="$(tr / \! <<<"$device")"
		ID_SERIAL=
		# apparently the usage of scsi_id changed over the times, so we try two ways to call it
		eval "$(scsi_id -g -x -n -s /block/"$sysfs" -d /dev/$device 2>/dev/null || scsi_id --export --whitelisted -d /dev/$device)"
		if test "$ID_SERIAL" ; then
			LogPrint "  $ID_SERIAL  /dev/$device  $((size/1024))MB"
			SCSI_ID_HAVE_RESULT=1
		fi
	done </proc/partitions
	LogPrint ""

	# sanity check, should be some disks listed here.
	if ! test "$SCSI_ID_HAVE_RESULT" ; then
		LogPrint "

WARNING ! Could not list any LUN IDs with scsi_id. Please tell us how your
system calls scsi_id. However, some disks just don't have any LUN ID. We
would like to know more about such systems and how they look.

"
	fi
fi
