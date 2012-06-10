# Check BACKUP_URL and OUTPUT_URL for incorrect usage

if [[ "$OUTPUT_URL" ]]; then
    local scheme=$(url_scheme $OUTPUT_URL)
    local server=$(url_host $OUTPUT_URL)
    local path=$(url_path $OUTPUT_URL)

    case "$scheme" in
        (file|tape|usb)
            [[ -z "$server" ]]
            StopIfError "OUTPUT_URL requires tripple slash ('$scheme:///$server$path' instead of '$OUTPUT_URL')"
            [[ "$path" ]]
            StopIfError "OUTPUT_URL is missing propper path ($OUTPUT_URL)"
            ;;
    esac
fi

if [[ "$BACKUP_URL" ]]; then
    local scheme=$(url_scheme $BACKUP_URL)
    local server=$(url_host $BACKUP_URL)
    local path=$(url_path $BACKUP_URL)

    case "$scheme" in
        (file|tape|usb)
            [[ -z "$server" ]]
            StopIfError "OUTPUT_URL for protocol $scheme requires tripple slash ('$scheme:///$server$path' instead of '$BACKUP_URL')"
            [[ "$path" ]]
            StopIfError "BACKUP_URL is missing propper path ($BACKUP_URL)"
            ;;
    esac
fi
