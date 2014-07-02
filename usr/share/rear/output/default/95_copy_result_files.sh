#
# copy resulting files to network output location

local scheme=$(url_scheme $OUTPUT_URL)
local host=$(url_host $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)
local opath=$(output_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
if [[ -z "$opath" || -z "$OUTPUT_URL" || "$scheme" == "obdr" || "$scheme" == "tape" ]]; then
    return 0
fi

LogPrint "Copying resulting files to $scheme location"

case "$scheme" in
    (nfs|cifs|usb|file|sshfs|davfs)
        # if called as mkbackuponly then we just don't have any result files.
        if test "$RESULT_FILES" ; then
            Log "Copying files '${RESULT_FILES[@]}' to $scheme location"
            cp $v "${RESULT_FILES[@]}" "${opath}/" >&2
            StopIfError "Could not copy files to $scheme location"
        fi
        echo "$VERSION_INFO" >"${opath}/VERSION"
        StopIfError "Could not create VERSION file on $scheme location"

        cp $v $(get_template "RESULT_usage_$OUTPUT.txt") "${opath}/README" >&2
        StopIfError "Could not copy usage file to $scheme location"

        # REAR_LOGFILE=/var/log/rear/rear-$HOSTNAME.log (name set by main script)
        cat "$REAR_LOGFILE" >"${opath}/rear.log"
        StopIfError "Could not copy $REAR_LOGFILE to $scheme location"
    ;;

    (fish|ftp|ftps|hftp|http|https|sftp)
    LogPrint "Copying files '${RESULT_FILES[*]}' to $scheme location"
    Log "lftp -c open $OUTPUT_URL; mput ${RESULT_FILES[*]}"
    lftp -c "open $OUTPUT_URL; mput ${RESULT_FILES[*]}"
    StopIfError "Problem transferring files to $OUTPUT_URL"
    ;;

    (rsync)
    [[ "$BACKUP" = "RSYNC" ]] && return 0   # output/RSYNC/default/90_copy_result_files.sh took care of it
    LogPrint "Copying files '${RESULT_FILES[@]}' to $scheme location"
    Log "rsync -a $v ${RESULT_FILES[@]} ${host}:${path}"
    rsync -a $v "${RESULT_FILES[@]}" "${host}:${path}"
    StopIfError "Problem transferring files to $OUTPUT_URL"
    ;;

    (*) BugError "Support for $scheme is not implemented yet."
    ;;
esac


Log "Saved $REAR_LOGFILE as rear.log"

