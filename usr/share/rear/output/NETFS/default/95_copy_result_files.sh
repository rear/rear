#
# copy resulting files to network backup location

local scheme=$(url_scheme $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)
local opath=$(output_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
if [[ -z "$opath" || -z "$OUTPUT_URL" || "$scheme" == "obdr" || "$scheme" == "tape" ]]; then
    return 0
fi

LogPrint "Copying resulting files to $scheme location"

# if called as mkbackuponly then we just don't have any result files.
if test "$RESULT_FILES" ; then
	Log "Copying files '${RESULT_FILES[@]}' to $scheme location"
	cp $v "${RESULT_FILES[@]}" "${opath}/" >&2
	StopIfError "Could not copy files to $scheme location"
fi

echo "$VERSION_INFO" >"${opath}/VERSION"
StopIfError "Could not create VERSION file on $scheme location"

cp $v $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "${opath}/README" >&2
StopIfError "Could not copy usage file to $scheme location"

# REAR_LOGFILE=/var/log/rear/rear-$HOSTNAME.log (name set by main script)
cat "$REAR_LOGFILE" >"${opath}/rear.log"
StopIfError "Could not copy $REAR_LOGFILE to $scheme location"

Log "Saved $REAR_LOGFILE as rear.log"

