# This script copies the ISO image to the target location in ISO_URL

# Check if ISO image is available
[[ -s "$ISO_DIR/$ISO_PREFIX.iso" ]]
StopIfError "Image $ISO_DIR/$ISO_PREFIX.iso is missing or empty."

# Check if we have a target location ISO_URL
if [[ -z "$ISO_URL" ]]; then
    continue
fi

local scheme="${ISO_URL%%://*}"
local server="${ISO_URL#*://}"
server="${server%%/*}"
local path="/${ISO_URL#*://*/}"

case "$scheme" in
    (file)
        LogPrint "Transferring ISO image to $path"
        cp -a "$ISO_DIR/$ISO_PREFIX.iso" $path
        if (( $? != 0 )); then
            Error "Problem transferring ISO image to $ISO_URL"
        fi
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring ISO image to $ISO_URL"
        lftp -c "open $ISO_URL; mkdir $path; mput -O $path $ISO_DIR/$ISO_PREFIX.iso"
        if (( $? != 0 )); then
            Error "Problem transferring ISO image to $ISO_URL"
        fi
        ;;
    (rsync)
        LogPrint "Transferring ISO image to $ISO_URL"
        rsync -a "$ISO_DIR/$ISO_PREFIX.iso" "$server:$path"
        if (( $? != 0 )); then
            Error "Problem transferring ISO image to $server:$path"
        fi
        ;;
    (*) BugError "Support for $scheme is not implemented yet.";;
esac
