### For OBDR, we need /dev/nst tape devices

orig_device=$TAPE_DEVICE
orig_url=$BACKUP_URL

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}
BACKUP_URL=${BACKUP_URL//\/st/\/nst}

if [[ "$orig_device" != "$TAPE_DEVICE" ]] ; then
    Log "Changed tape device from $orig_device to $TAPE_DEVICE"
fi
