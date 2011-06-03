# Provide the necessary variables to make NETFS use TAPE information

if [[ -z "$NETFS_URL" ]]; then
    [[ "$TAPE_DEVICE" ]]
    StopIfError "You must specify either NETFS_URL or TAPE_DEVICE !"

    NETFS_URL="tape://$TAPE_DEVICE"
fi
