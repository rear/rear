# In case we have bareos, we could use the device from the bareos configuration

# We construct the TAPE_DEVICE based on the Bareos device name in the Bareos
# configuration

if [[ "$BACKUP" != "BAREOS" ]]; then
    return
fi

if [[ -z "$TAPE_DEVICE" && "$BEXTRACT_DEVICE" ]]; then
    has_binary btape
    LogIfError "btape binary not found, unable to handle BEXTRACT_DEVICE '$BEXTRACT_DEVICE'"

    TAPE_DEVICE="$(echo cap | btape $BEXTRACT_DEVICE | awk '/^Device name/ { print $3 }')"

    [[ "$TAPE_DEVICE" ]]
    StopIfError "Either tape device $BEXTRACT_DEVICE is missing, or it has no tape inserted."
fi
