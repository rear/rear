# make backup using the RSYNC method
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

local backup_prog_rc
local backup_log_message

local host path

host="$(rsync_host "$BACKUP_URL")"
path="$(rsync_path "$BACKUP_URL")"

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $TMP_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $TMP_DIR/backup-exclude.txt

LogPrint "Creating $BACKUP_PROG backup on '${host}:${path}'"

ProgressStart "Running backup operation"
(
	case "$(basename $BACKUP_PROG)" in

		(rsync)
			# We are in a subshell, so this change will not propagate to later scripts
			BACKUP_RSYNC_OPTIONS+=( --one-file-system --delete --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded )

			case $(rsync_proto "$BACKUP_URL") in

				(ssh)
					Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) "$(rsync_remote_full "$BACKUP_URL")/backup"
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) \
					"$(rsync_remote_full "$BACKUP_URL")/backup"
					;;

				(rsync)
					$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(cat $TMP_DIR/backup-include.txt) \
					"$(rsync_remote_full "$BACKUP_URL")/backup"
					;;

			esac
			;;

		(*)
			# no other backup programs foreseen than rsync so far
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
	echo $(ssh $(rsync_remote_ssh "$BACKUP_URL") df -P ${path} 2>/dev/null | tail -1 | awk '{print $5}' | sed -e 's/%//')
}

check_remote_du() {
	x=$(ssh $(rsync_remote_ssh "$BACKUP_URL") du -sb $(rsync_path_full "$BACKUP_URL")/backup 2>/dev/null | awk '{print $1}')
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
			[[ $(check_remote_df) -eq 100 ]] && Error "Disk is full on system ${host}"
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

			ProgressInfo "Backed up $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
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
backup_prog_rc="$(cat $TMP_DIR/retval)"

sleep 1
# everyone should see this warning, even if not verbose
test "$backup_prog_rc" -gt 0 && Error "
There was an error (${rsync_err_msg[$backup_prog_rc]}) during backup creation.
Please check the destination and see '$RUNTIME_LOGFILE' for more information.

If the error is related to files that cannot and should not be saved by
$BACKUP_PROG, they should be excluded from the backup.

"

backup_log_message="$(tail -14 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log)"
if [ $backup_prog_rc -eq 0 -a "$backup_log_message" ] ; then
	LogPrint "$backup_log_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Backed up $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

