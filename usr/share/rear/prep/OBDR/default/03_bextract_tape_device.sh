# In case we have bacula, we could use the device from the bacula configuration

# We construct the TAPE_DEVICE based on the Bacula device name in the bacula
# configuration

if [[ "$BACKUP" != "BACULA" ]]; then
    return
fi

if [[ -z "$TAPE_DEVICE" && "$BEXTRACT_DEVICE" ]]; then
    type -p btape &>/dev/null
    LogIfError "btape binary not found, unable to handle BEXTRACT_DEVICE '$BEXTRACT_DEVICE'"

    TAPE_DEVICE="$(echo cap | btape $BEXTRACT_DEVICE | awk '/^Device name/ { print $3 }')"

    [[ "$TAPE_DEVICE" ]]
    StopIfError "Either tape device $BEXTRACT_DEVICE is missing, or it has no tape inserted."
fi

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}
