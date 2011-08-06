#
# copy resulting files to network backup location


# do not do this for tapes
local scheme=$(url_scheme $OUTPUT_URL)
case $scheme in
    (tape|usb|file)
        return 0
        ;;
esac

LogPrint "Copying resulting files to $scheme location"

# if called as mkbackuponly then we just don't have any result files.
if test "$RESULT_FILES" ; then
	Log "Copying files '${RESULT_FILES[@]}' to $scheme location"
	cp $v "${RESULT_FILES[@]}" "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/" >&2
	StopIfError "Could not copy files to $scheme location"
fi

echo "$VERSION_INFO" >"${BUILD_DIR}/outputfs/${NETFS_PREFIX}/VERSION"
StopIfError "Could not create VERSION file on $scheme location"

cp $v $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "${BUILD_DIR}/outputfs/${NETFS_PREFIX}/README" >&2
StopIfError "Could not copy usage file to $scheme location"

cat "$LOGFILE" >"${BUILD_DIR}/outputfs/${NETFS_PREFIX}/rear.log"
StopIfError "Could not copy $LOGFILE to $scheme location"

Log "Saved $LOGFILE as ${NETFS_PREFIX}/rear.log"
