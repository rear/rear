# Provide the necessary variables to make NETFS use USB information

if [[ -z "$NETFS_URL" ]]; then
    if [[ "$USB_DEVICE" ]]; then
        NETFS_URL="usb://$USB_DEVICE"
    else
        Error "You must specify either NETFS_URL or USB_DEVICE !"
    fi
fi

USB_PREFIX="rear/$(uname -n)/$(date +%Y%m%d.%H%M)"
NETFS_PREFIX="$USB_PREFIX"
