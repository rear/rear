# Generate code for low-level formatting of a DASD

dasd_format_code() {
    local device size blocksize layout dasdtype dasdcyls

    device="$1"
    size="$2"
    blocksize="$3"
    layout="$4"
    dasdtype="$5"
    dasdcyls="$6"

    has_binary dasdfmt || Error "Cannot find 'dasdfmt' command"

    LogPrint 'dasdfmt:' $device ', blocksize:' $blocksize ', layout:' $layout
    echo "dasdfmt -b $blocksize -d $layout -y $device"
}
