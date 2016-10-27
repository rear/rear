### set USB device from OUTPUT_URL
if [[ -z "$USB_DEVICE" ]] && [[ "$OUTPUT_URL" ]]; then
    local scheme=$(url_scheme $OUTPUT_URL)
    local path=$(url_path $OUTPUT_URL)
    case $scheme in
        (usb)
            USB_DEVICE="$path"
            ;;
    esac
fi

USB_PREFIX="rear/$HOSTNAME/$(date +%Y%m%d.%H%M)"

### Change NETFS_PREFIX to USB_PREFIX if our backup URL is on USB
if [[ "$BACKUP_URL" ]] ; then
    local scheme=$(url_scheme $BACKUP_URL)
    case $scheme in
        (usb)
            NETFS_PREFIX="$USB_PREFIX"
            ;;
    esac
fi
