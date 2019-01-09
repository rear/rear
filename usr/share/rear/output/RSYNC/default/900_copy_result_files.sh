#
# copy resulting files to remote network (backup) location

LogPrint "Copying resulting files to $OUTPUT_URL location"

# if called as mkbackuponly then we just don't have any result files.
if test "$RESULT_FILES" ; then
    Log "Copying files '${RESULT_FILES[@]}' to $OUTPUT_URL location"
    cp $v "${RESULT_FILES[@]}" "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" >&2
    StopIfError "Could not copy files to local rsync location"
fi

echo "$VERSION_INFO" >"${TMP_DIR}/rsync/${RSYNC_PREFIX}/VERSION"
StopIfError "Could not create VERSION file on local rsync location"

cp $v $(get_template "RESULT_usage_$OUTPUT.txt") "${TMP_DIR}/rsync/${RSYNC_PREFIX}/README" >&2
StopIfError "Could not copy usage file to local rsync location"

cat "$RUNTIME_LOGFILE" >"${TMP_DIR}/rsync/${RSYNC_PREFIX}/rear.log"
StopIfError "Could not copy $RUNTIME_LOGFILE to local rsync location"

case $RSYNC_PROTO in

    (ssh)
    Log "$BACKUP_PROG -a ${TMP_DIR}/rsync/${RSYNC_PREFIX}/ ${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/"
    $BACKUP_PROG -a "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/${RSYNC_PREFIX}/" 2>/dev/null
    StopIfError "Could not copy '${RESULT_FILES[@]}' to $OUTPUT_URL location"
    ;;

    (rsync)
    Log "$BACKUP_PROG -a ${TMP_DIR}/rsync/${RSYNC_PREFIX}/ ${BACKUP_RSYNC_OPTIONS[@]} ${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/"
    $BACKUP_PROG -a "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" ${BACKUP_RSYNC_OPTIONS[@]} "${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/${RSYNC_PATH}/${RSYNC_PREFIX}/" 2>/dev/null
    StopIfError "Could not copy '${RESULT_FILES[@]}' to $OUTPUT_URL location"
    ;;

esac

# cleanup the temporary space (need it for the log file during backup)
rm -rf "${TMP_DIR}/rsync/${RSYNC_PREFIX}/"
LogIfError "Could not cleanup temoprary rsync space: ${TMP_DIR}/rsync/${RSYNC_PREFIX}/"
