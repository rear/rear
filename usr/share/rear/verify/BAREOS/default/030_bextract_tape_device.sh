# In case we have bareos, we could use the device from the bareos configuration

# We construct the TAPE_DEVICE based on the Bareos device name in the Bareos
# configuration

if [[ -z "$TAPE_DEVICE" && "$BEXTRACT_DEVICE" ]]; then
    TAPE_DEVICE="$(echo cap | btape "$BEXTRACT_DEVICE" | awk '/^Device name/ { print $3 }')"

    [[ "$TAPE_DEVICE" ]]
    StopIfError "Either tape device $BEXTRACT_DEVICE is missing, or it has no tape inserted."
fi
