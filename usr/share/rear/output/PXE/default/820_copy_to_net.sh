
# 820_copy_to_net.sh

# Check if we have a target location OUTPUT_URL
test "$OUTPUT_URL" || return 0

local scheme=$( url_scheme $OUTPUT_URL )
local result_file=""
local dest_dir=""

case "$scheme" in
    (nfs|cifs|usb|tape|file|davfs)
        # The ISO has already been transferred by NETFS.
        return 0
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring PXE files to $OUTPUT_URL"
        for result_file in "${RESULT_FILES[@]}" ; do
            # OUTPUT_URL for lftp transfers will look something like:
            # "<fish|ftp|ftps|hftp|http|https|sftp>://<host_name>/<destination_directory>"
            # Using `cut' for printing 4th field with "/" delimiter (.. | cut -d/ -f4-),
            # will strip leading "<protocol>://<hostname>/" from OUTPUT_URL
            # and by prefixing "/" we will get absolute path to destination directory.
            dest_dir="/$(echo $OUTPUT_URL | cut -d/ -f4-)"

            # Make sure that destination directory exists, otherwise lftp would copy
            # RESULT_FILES into last available directory in the path.
            # e.g. OUTPUT_URL=sftp://<host_name>/iso/server1 and have "/iso/server1"
            # directory missing, would upload RESULT_FILES into sftp://<host_name>/iso/
            lftp -c "open $OUTPUT_URL; mkdir -fp ${dest_dir}"

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

