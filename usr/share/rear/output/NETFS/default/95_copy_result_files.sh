#
# copy resulting files to network backup location

# do not do this for tapes
if [ "$NETFS_PROTO" == "tape" -o "$NETFS_PROTO" == "obdr" ]; then
	return 0
fi

test ${#RESULT_FILES[@]} -gt 0 || Error "No files to copy (RESULT_FILES is empty)"

test -d "${BUILD_DIR}/netfs/${NETFS_PREFIX}" || Error "'${BUILD_DIR}/netfs/${NETFS_PREFIX}/' not a directory !"

Log "Copying files '${RESULT_FILES[@]}' to $NETFS_PROTO location"

ProgressStart "Copying resulting files to $NETFS_PROTO location"
cp "${RESULT_FILES[@]}" "${BUILD_DIR}/netfs/${NETFS_PREFIX}/" 1>&8
ProgressStopIfError $? "Could not copy files to $NETFS_PROTO location"
echo "$VERSION_INFO" >"${BUILD_DIR}/netfs/${NETFS_PREFIX}/VERSION"
ProgressStopIfError $? "Could not create VERSION file on $NETFS_PROTO location"
cp $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "${BUILD_DIR}/netfs/${NETFS_PREFIX}/README" 1>&8
ProgressStopOrError $? "Could not copy usage file to $NETFS_PROTO location"
if [ -e "$LOGFILE" ]; then
	contents="$(< $LOGFILE)"
	case $NETFS_PROTO in
		usb ) echo "${contents}" | tee 1>&8 "${BUILD_DIR}/netfs/${NETFS_PREFIX}/rear.log"
		      Log "Saved $LOGFILE as ${NETFS_PREFIX}/rear.log" ;;
		  * ) echo "${contents}" | tee 1>&8 "${BUILD_DIR}/netfs/${NETFS_PREFIX}/rear-$(date -Iseconds).log"
		      Log "Saved $LOGFILE as ${NETFS_PREFIX}/rear-$(date -Iseconds).log" ;;
	esac
fi
