# make backup using the RSYNC method

Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $BUILD_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $BUILD_DIR/backup-exclude.txt

LogPrint "Creating $BACKUP_PROG archive on '${RSYNC_HOST}:${RSYNC_PATH}'"

ProgressStart "Running archive operation"
(
	case "$(basename $BACKUP_PROG)" in

		(rsync)
			BACKUP_OPTS="--sparse --archive --hard-links --one-file-system --verbose --delete --numeric-ids --exclude-from=$BUILD_DIR/backup-exclude.txt --delete-excluded --compress --stats"
			if [ "$RSYNC_USER" != "root" -a $RSYNC_PROTOCOL_VERSION -gt 29 ]; then
				BACKUP_OPTS2=" $RSYNC_FAKE_SUPER"
			fi

			case $RSYNC_PROTO in

				(ssh)
					Log $BACKUP_PROG $BACKUP_OPTS $BACKUP_OPTS2 $(cat $BUILD_DIR/backup-include.txt) "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup"
					$BACKUP_PROG $BACKUP_OPTS $BACKUP_OPTS2 $(cat $BUILD_DIR/backup-include.txt) \
					"${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/backup" 2>/dev/null
					;;

				(rsync)
					$BACKUP_PROG $BACKUP_OPTS $BACKUP_OPTS2 $(cat $BUILD_DIR/backup-include.txt) \
					"${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/backup"
					;;

			esac
			;;

		(*)
			# no other backup programs foreseen then rsync so far
			:
			;;

	esac
	echo $? >$BUILD_DIR/retval
) >"${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log" &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

function get_size () {
	echo $(stat --format '%s' "/$1" 2>/dev/null)
}

# make sure that we don't fall for an old size info
unset size
# while the backup runs in a sub-process, display some progress information to the user
case "$(basename $BACKUP_PROG)" in

	(rsync)
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			fsize="$(get_size $(tail -1 "${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log"))"
			size=$((size+fsize))
			echo "INFO Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]" >&8
		done
		;;

	(*)
		echo "INFO Archiving" >&8
		while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
			ProgressStep
		done
		;;

esac
ProgressStop

wait $BackupPID

transfertime="$((SECONDS-starttime))"
_rc="$(cat $BUILD_DIR/retval)"

sleep 1
# everyone should see this warning, even if not verbose
test "$_rc" -gt 0 && VERBOSE=1 LogPrint "WARNING !
There was an error (${rsync_err_msg[$_rc]}) during archive creation.
Please check the archive and see '$LOGFILE' for more information.

Since errors are oftenly related to files that cannot be saved by
$BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !

"

_message="$(tail -14 ${BUILD_DIR}/${BACKUP_PROG_ARCHIVE}.log)"
if [ $_rc -eq 0 -a "$_message" ] ; then
	LogPrint "$_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

