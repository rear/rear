# Provide the necessary variables to make NETFS use TAPE information

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}

if [[ -z "$NETFS_URL" ]]; then
    [[ "$TAPE_DEVICE" ]]
    StopIfError "You must specify either NETFS_URL or TAPE_DEVICE !"

    NETFS_URL="tape://$TAPE_DEVICE"
fi
