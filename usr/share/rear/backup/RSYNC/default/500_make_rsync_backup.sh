# make backup using the RSYNC method
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $TMP_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $TMP_DIR/backup-exclude.txt

LogPrint "Creating $BACKUP_PROG archive on '${RSYNC_HOST}:${RSYNC_PATH}'"

ProgressStart "Running archive operation"
(
	case "$(basename $BACKUP_PROG)" in

		(rsync)
			BACKUP_RSYNC_OPTIONS+=( --one-file-system --delete --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded )

			case $RSYNC_PROTO in

				(ssh)
					Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) \
					"${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"
					;;

				(rsync)
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) \
					"${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/backup"
					;;

			esac
			;;

		(*)
			# no other backup programs foreseen then rsync so far
			:
			;;

	esac
	echo $? >$TMP_DIR/retval
) >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" &
BackupPID=$!
starttime=$SECONDS

sleep 3 # Give the backup software a good chance to start working

get_size() {
	echo $(stat --format '%s' "/$1" 2>/dev/null)
}

check_remote_df() {
	echo $(ssh ${RSYNC_USER}@${RSYNC_HOST} df -P ${RSYNC_PATH} 2>/dev/null | tail -1 | awk '{print $5}' | sed -e 's/%//')
}

check_remote_du() {
	x=$(ssh ${RSYNC_USER}@${RSYNC_HOST} du -sb ${RSYNC_PATH}/${RSYNC_PREFIX}/backup 2>/dev/null | awk '{print $1}')
	[[ -z "${x}" ]] && x=0
	echo $x
}

# make sure that we don't fall for an old size info
unset size
# while the backup runs in a sub-process, display some progress information to the user
test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
case "$(basename $BACKUP_PROG)" in

	(rsync)
		ofile=""
		i=0
		while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
			i=$((i+1))
			[[ $i -gt 300 ]] && i=0
			case $i in

			300)
			[[ $(check_remote_df) -eq 100 ]] && Error "Disk is full on system ${RSYNC_HOST}"
			;;

			15|30|45|60|75|90|105|120|135|150|165|180|195|210|225|240|255|270|285)
			size=$(check_remote_du)
			;;

			* )
			nfile="$(tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log")"
			#fsize="$(get_size $(tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"))"
			[[ "$nfile" != "$ofile" ]] && {
				fsize="$(get_size "$nfile")"
				size=$((size+fsize))
				ofile="$nfile"
				}
			;;
			esac

			ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;

	(*)
		ProgressInfo "Archiving"
		while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
			ProgressStep
		done
		;;

esac
ProgressStop

wait $BackupPID

transfertime="$((SECONDS-starttime))"
_rc="$(cat $TMP_DIR/retval)"

sleep 1
# everyone should see this warning, even if not verbose
test "$_rc" -gt 0 && VERBOSE=1 LogPrint "WARNING !
There was an error (${rsync_err_msg[$_rc]}) during archive creation.
Please check the archive and see '$RUNTIME_LOGFILE' for more information.

Since errors are often related to files that cannot be saved by
$BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !

"

_message="$(tail -14 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log)"
if [ $_rc -eq 0 -a "$_message" ] ; then
	LogPrint "$_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

