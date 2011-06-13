#
# copy resulting files to remote network (backup) location

LogPrint "Copying resulting files to $RSYNC_URL location"

# if called as mkbackuponly then we just don't have any result files.
if test "$RESULT_FILES" ; then
	Log "Copying files '${RESULT_FILES[@]}' to $RSYNC_URL location"
	cp $v "${RESULT_FILES[@]}" "${BUILD_DIR}/rsync/${RSYNC_PREFIX}/" >&2
	StopIfError "Could not copy files to local rsync location"
	
fi

echo "$VERSION_INFO" >"${BUILD_DIR}/rsync/${RSYNC_PREFIX}/VERSION"
StopIfError "Could not create VERSION file on local rsync location"

cp $v $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "${BUILD_DIR}/rsync/${RSYNC_PREFIX}/README" >&2
StopIfError "Could not copy usage file to local rsync location"

cat "$LOGFILE" >"${BUILD_DIR}/rsync/${RSYNC_PREFIX}/rear.log"
StopIfError "Could not copy $LOGFILE to local rsync location"

case $RSYNC_PROTO in

	(ssh)

		Log "$BACKUP_PROG -a ${BUILD_DIR}/rsync/${RSYNC_PREFIX}/ ${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/"
		$BACKUP_PROG -a "${BUILD_DIR}/rsync/${RSYNC_PREFIX}/" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/" 2>/dev/null
		;;

	(rsync)

		Log "$BACKUP_PROG -a ${BUILD_DIR}/rsync/${RSYNC_PREFIX}/ ${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/"
		$BACKUP_PROG -a "${BUILD_DIR}/rsync/${RSYNC_PREFIX}/" "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/"
		;;

esac

