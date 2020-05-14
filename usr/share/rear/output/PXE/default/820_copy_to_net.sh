
# 820_copy_to_net.sh

# Check if we have a target location OUTPUT_URL
test "$OUTPUT_URL" || return 0

local scheme=$( url_scheme $OUTPUT_URL )
local result_file=""

case "$scheme" in
    (nfs|cifs|usb|tape|file|davfs)
        # The ISO has already been transferred by NETFS.
        return 0
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring PXE files to $OUTPUT_URL"
        for result_file in "${RESULT_FILES[@]}" ; do
            LogPrint "Transferring file: $result_file"
            lftp -c "open $OUTPUT_URL; $OUTPUT_LFTP_OPTIONS mput $result_file" || Error "lftp failed to transfer '$result_file' to '$OUTPUT_URL' (lftp exit code: $?)"
        done
        ;;
    (rsync)
        LogPrint "Transferring PXE files to $OUTPUT_URL"
        for result_file in "${RESULT_FILES[@]}" ; do
            LogPrint "Transferring file: $result_file"
            rsync -a $v "$result_file" "$OUTPUT_URL" || Error "Problem transferring '$result_file' to $OUTPUT_URL"
        done
        ;;
    (*) Error "Invalid scheme '$scheme' in '$OUTPUT_URL'."
        ;;
esac

