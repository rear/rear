# This script copies the ISO image to the target location in OUTPUT_URL

# Check if ISO image is available
[[ -s "$ISO_DIR/$ISO_PREFIX.iso" ]]
StopIfError "Image $ISO_DIR/$ISO_PREFIX.iso is missing or empty."

# Check if we have a target location OUTPUT_URL
if [[ -z "$OUTPUT_URL" ]]; then
    return
fi

local scheme=$(url_scheme $OUTPUT_URL)
local server=$(url_host $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)

case "$scheme" in
    (nfs|cifs|usb|tape|file)
        # The ISO has already been transferred by NETFS.
        return 0
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring ISO image to $OUTPUT_URL"
        lftp -c "open $OUTPUT_URL; mput $ISO_DIR/$ISO_PREFIX.iso"
        StopIfError "Problem transferring ISO image to $OUTPUT_URL"
        ;;
    (rsync)
        LogPrint "Transferring ISO image to $OUTPUT_URL"
        rsync -a $v "$ISO_DIR/$ISO_PREFIX.iso" "$OUTPUT_URL"
        StopIfError "Problem transferring ISO image to $OUTPUT_URL"
        ;;
    (*) BugError "Support for $scheme is not implemented yet.";;
esac
