# Provide the necessary variables to make NETFS use USB information

if [[ -z "$BACKUP_URL" ]]; then
    [[ "$USB_DEVICE" ]]
    StopIfError "You must specify either BACKUP_URL or USB_DEVICE !"

    BACKUP_URL="usb://$USB_DEVICE"
fi

if [[ -z "$OUTPUT_URL" ]]; then
    [[ "$USB_DEVICE" ]]
    StopIfError "You must specify either OUTPUT_URL or USB_DEVICE !"

    OUTPUT_URL="usb://$USB_DEVICE"
fi
