### set USB device from OUTPUT_URL
if [[ -z "$USB_DEVICE" ]] && [[ "$OUTPUT_URL" ]]; then
    local scheme="$( url_scheme "$OUTPUT_URL" )"
    local path="$( url_path "$OUTPUT_URL" )"
    case "$scheme" in
        (usb)
            USB_DEVICE="$path"
            ;;
    esac
fi

# Set USB_PREFIX:
# Use plain $USB_SUFFIX and not "$USB_SUFFIX" because when USB_SUFFIX contains only blanks
# test "$USB_SUFFIX" would result true because test " " results true:
if test $USB_SUFFIX ; then
    # When USB_SUFFIX is set the compliance mode is used which means
    USB_PREFIX="rear/$HOSTNAME/$USB_SUFFIX"
    # which results that backup on USB works in compliance with backup on NFS
    # which means a fixed backup directory and no automated backups cleanup
    # see https://github.com/rear/rear/issues/1164
else
    # When USB_SUFFIX is unset, empty, or contains only blanks
    # the default mode for backup on USB is used which means
    USB_PREFIX="rear/$HOSTNAME/$( date +%Y%m%d.%H%M )"
    # which results multiple timestamp backup directories
    # plus automated backups cleanup via USB_RETAIN_BACKUP_NR
fi

test "$USB_PREFIX" || USB_PREFIX="rear/$HOSTNAME/$(date +%Y%m%d.%H%M)"

### Change NETFS_PREFIX to USB_PREFIX if our backup URL is on USB
if [[ "$BACKUP_URL" ]] ; then
    local scheme="$( url_scheme "$BACKUP_URL") "
    case "$scheme" in
        (usb)
            NETFS_PREFIX="$USB_PREFIX"
            ;;
    esac
fi
