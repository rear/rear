# Create RSYNC_PREFIX under the local BUILD_DIR and also on remote rsync server
# RSYNC_PREFIX=$(uname -n) as set in default.conf

# create temporary local work-spaces to collect files (we already make the remote backup dir with the correct mode!!)
mkdir -p -m0750 "${BUILD_DIR}/rsync/${RSYNC_PREFIX}"
StopIfError "Could not mkdir '${BUILD_DIR}/rsync/${RSYNC_PREFIX}'"
mkdir -p -m0755 "${BUILD_DIR}/rsync/${RSYNC_PREFIX}/backup"
StopIfError "Could not mkdir '${BUILD_DIR}/rsync/${RSYNC_PREFIX}/backup'"

case $RSYNC_PROTO in

	(ssh)
		$BACKUP_PROG -a -r "${BUILD_DIR}/rsync/${RSYNC_PREFIX}" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}" 2>/dev/null 1>&8
		StopIfError "Could not create '${RSYNC_PATH}/${RSYNC_PREFIX}' on remote ${RSYNC_HOST}"
		;;

	(rsync)
		$BACKUP_PROG -a -r "${BUILD_DIR}/rsync/${RSYNC_PREFIX}" "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/" 1>&8
		StopIfError "Could not create '${RSYNC_PATH}/${RSYNC_PREFIX}' on remote ${RSYNC_HOST}"
		;;

esac
