# In case we have bacula, we could use the device from the bacula configuration

# We construct the ISO_URL based on the Bacula device name in the bacula
# configuration

if [[ -z "$ISO_URL" ]]; then
    if [[ -z "$BEXTRACT_DEVICE" ]]; then
        Error "Configuration is missing ISO_URL or BEXTRACT_DEVICE"
    fi
    tape_device="$(echo cap | btape $BEXTRACT_DEVICE | awk '/^Device name/ { print $3 }')"
    if [[ -z "$tape_device" ]]; then
        Error "Either tape device $BEXTRACT_DEVICE is missing, or it has no tape inserted."
    fi
    ISO_URL=obdr://${tape_device//\/st/\/nst}
fi

if [[ -z "$TAPE_DEVICE" ]]; then
    TAPE_DEVICE=$tape_device
fi
