# In case we have bacula, we could use the device from the bacula configuration

# We construct the TAPE_DEVICE based on the Bacula device name in the bacula
# configuration

if [[ -z "$TAPE_DEVICE" ]]; then
    if [[ "$BEXTRACT_DEVICE" ]]; then
        TAPE_DEVICE="$(echo cap | btape $BEXTRACT_DEVICE | awk '/^Device name/ { print $3 }')"

        [[ "$TAPE_DEVICE" ]]
        StopIfError "Either tape device $BEXTRACT_DEVICE is missing, or it has no tape inserted."
    fi
fi

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}
