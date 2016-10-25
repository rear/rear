#
# copy resulting files to network output location

local scheme=$( url_scheme $OUTPUT_URL )
local host=$( url_host $OUTPUT_URL )
local path=$( url_path $OUTPUT_URL )
local opath=$( output_path $scheme $path )

# if $opath is empty return silently (e.g. scheme tape)
if [[ -z "$opath" || -z "$OUTPUT_URL" || "$scheme" == "obdr" || "$scheme" == "tape" ]]; then
    return 0
fi

LogPrint "Copying resulting files to $scheme location"

echo "$VERSION_INFO" >"$TMP_DIR/VERSION" || Error "Could not create $TMP_DIR/VERSION file"
if test -s $(get_template "RESULT_usage_$OUTPUT.txt") ; then
    cp $v $(get_template "RESULT_usage_$OUTPUT.txt") "$TMP_DIR/README" >&2
    StopIfError "Could not copy '$(get_template RESULT_usage_$OUTPUT.txt)'"
fi

# REAR_LOGFILE=/var/log/rear/rear-$HOSTNAME.log (name set by main script)
cat "$REAR_LOGFILE" > "$TMP_DIR/rear.log" || Error "Could not copy $REAR_LOGFILE to $TMP_DIR/rear.log"

# Add the README, VERSION and rear.log to the RESULT_FILES array
RESULT_FILES=( ${RESULT_FILES[*]} "$TMP_DIR/VERSION" "$TMP_DIR/README" "$TMP_DIR/rear.log" )

case "$scheme" in
    (nfs|cifs|usb|file|sshfs|ftpfs|davfs)
        # if called as mkbackuponly then we just don't have any result files.
        if test "$RESULT_FILES" ; then
            Log "Copying result files '${RESULT_FILES[@]}' to $opath at $scheme location"
            cp $v "${RESULT_FILES[@]}" "${opath}/" >&2 || Error "Could not copy result files to $opath at $scheme location"
        fi
    ;;

    (fish|ftp|ftps|hftp|http|https|sftp)
    LogPrint "Copying result files '${RESULT_FILES[*]}' to $scheme location"
    Log "lftp -c open $OUTPUT_URL; mput ${RESULT_FILES[*]}"
    lftp -c "open $OUTPUT_URL; mput ${RESULT_FILES[*]}" || Error "Problem transferring result files to $OUTPUT_URL"
    ;;

    (rsync)
    [[ "$BACKUP" = "RSYNC" ]] && return 0   # output/RSYNC/default/90_copy_result_files.sh took care of it
    LogPrint "Copying result files '${RESULT_FILES[@]}' to $scheme location"
    Log "rsync -a $v ${RESULT_FILES[@]} ${host}:${path}"
    rsync -a $v "${RESULT_FILES[@]}" "${host}:${path}" || Error "Problem transferring result files to $OUTPUT_URL"
    ;;

    (*) Error "Invalid scheme '$scheme' in '$OUTPUT_URL'."
    ;;
esac

Log "Saved $REAR_LOGFILE as rear.log"

