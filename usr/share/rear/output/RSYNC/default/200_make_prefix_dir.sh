# Create RSYNC_PREFIX under the local TMP_DIR and also on remote rsync server
# RSYNC_PREFIX=$HOSTNAME as set in default.conf

# create temporary local work-spaces to collect files (we already make the remote backup dir with the correct mode!!)
mkdir -p $v -m0750 "${TMP_DIR}/rsync/${RSYNC_PREFIX}" >&2
StopIfError "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}'"
mkdir -p $v -m0755 "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup" >&2
StopIfError "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup'"

case $RSYNC_PROTO in

	(ssh)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}" >/dev/null 2>&1
		StopIfError "Could not create '${RSYNC_PATH}/${RSYNC_PREFIX}' on remote ${RSYNC_HOST}"
		;;

	(rsync)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" ${BACKUP_RSYNC_OPTIONS[@]} "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/" >/dev/null
		StopIfError "Could not create '${RSYNC_PATH}/${RSYNC_PREFIX}' on remote ${RSYNC_HOST}"
		;;

esac
