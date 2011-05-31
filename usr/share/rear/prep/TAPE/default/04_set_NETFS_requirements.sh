# Provide the necessary variables to make NETFS use TAPE information

if [[ -z "$NETFS_URL" ]]; then
    if [[ "$TAPE_DEVICE" ]]; then
        NETFS_URL="tape://$TAPE_DEVICE"
    else
        Error "You must specify either NETFS_URL or TAPE_DEVICE !"
    fi
fi
