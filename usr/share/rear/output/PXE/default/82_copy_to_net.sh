# #82_copy_to_net.sh

# Check if we have a target location OUTPUT_URL
if [[ -z "$OUTPUT_URL" ]]; then
    return
fi

local scheme=$(url_scheme $OUTPUT_URL)
local server=$(url_host $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)

case "$scheme" in
    (nfs|cifs|usb|tape|file|davfs)
        # The ISO has already been transferred by NETFS.
        return 0
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring PXE files to $OUTPUT_URL"
        for i in "${RESULT_FILES[@]}"
          do
            LogPrint "Transferring file: $i"
            lftp -c "open $OUTPUT_URL; mput $i"
          done
        StopIfError "Problem transferring PXE files to $OUTPUT_URL"
        ;;
    (rsync)
        LogPrint "Transferring PXE files to $OUTPUT_URL"
        for i in "${RESULT_FILES[@]}"
          do
            LogPrint "Transferring file: $i"
            rsync -a $v "$i" "$OUTPUT_URL"
          done
        StopIfError "Problem transferring PXE files to $OUTPUT_URL"
        ;;
    (*) BugError "Support for $scheme is not implemented yet.";;
esac
