# Provide the necessary variables to make NETFS use TAPE information

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}

if [[ -z "$BACKUP_URL" ]]; then
    [[ "$TAPE_DEVICE" ]]
    StopIfError "You must specify either BACKUP_URL or TAPE_DEVICE !"

    BACKUP_URL="tape://$TAPE_DEVICE"
fi
