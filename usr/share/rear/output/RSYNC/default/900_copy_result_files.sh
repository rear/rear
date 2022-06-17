#
# copy resulting files to remote network (backup) location

local proto
proto="$(rsync_proto "$OUTPUT_URL")"

LogPrint "Copying resulting files to $OUTPUT_URL location"

# if called as mkbackuponly then we just don't have any result files.
if test "$RESULT_FILES" ; then
    Log "Copying files '${RESULT_FILES[*]}' to $OUTPUT_URL location"
    cp $v "${RESULT_FILES[@]}" "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" \
        || Error "Could not copy files to local rsync location"
fi

echo "$VERSION_INFO" >"${TMP_DIR}/rsync/${RSYNC_PREFIX}/VERSION" \
    || Error "Could not create VERSION file on local rsync location"

cp $v $(get_template "RESULT_usage_$OUTPUT.txt") "${TMP_DIR}/rsync/${RSYNC_PREFIX}/README" \
    || Error "Could not copy usage file to local rsync location"

cat "$RUNTIME_LOGFILE" >"${TMP_DIR}/rsync/${RSYNC_PREFIX}/rear.log" \
    || Error "Could not copy $RUNTIME_LOGFILE to local rsync location"

case $proto in

    (ssh)
    Log "$BACKUP_PROG -a ${TMP_DIR}/rsync/${RSYNC_PREFIX}/ $(rsync_remote_full "$OUTPUT_URL")/"
    # FIXME: Add an explanatory comment why "2>/dev/null" is useful here
    # or remove it according to https://github.com/rear/rear/issues/1395
    $BACKUP_PROG -a "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" "$(rsync_remote_full "$OUTPUT_URL")/" 2>/dev/null \
        || Error "Could not copy '${RESULT_FILES[*]}' to $OUTPUT_URL location"
    ;;

    (rsync)
    Log "$BACKUP_PROG -a ${TMP_DIR}/rsync/${RSYNC_PREFIX}/ ${BACKUP_RSYNC_OPTIONS[*]} $(rsync_remote_full "$OUTPUT_URL")/"
    # FIXME: Add an explanatory comment why "2>/dev/null" is useful here
    # or remove it according to https://github.com/rear/rear/issues/1395
    $BACKUP_PROG -a "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" "${BACKUP_RSYNC_OPTIONS[@]}" "$(rsync_remote_full "$OUTPUT_URL")/" 2>/dev/null \
        || Error "Could not copy '${RESULT_FILES[*]}' to $OUTPUT_URL location"
    ;;

esac

# cleanup the temporary space (need it for the log file during backup)
rm -rf "${TMP_DIR}/rsync/${RSYNC_PREFIX}/" \
    || Log "Could not cleanup temporary rsync space: ${TMP_DIR}/rsync/${RSYNC_PREFIX}/"
