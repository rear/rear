# Provide the necessary variables to use tape/obdr information

if [[ "$BACKUP_URL" ]] ; then
    backup_scheme="$(url_scheme "$BACKUP_URL")"
    if [[ "$backup_scheme" == tape || "$backup_scheme" == obdr ]] ; then
        testdevice="$(url_path "$BACKUP_URL")"
        ### Complain when both are specified, but don't match
        if [[ "$TAPE_DEVICE" && "$TAPE_DEVICE" != "$testdevice" ]]; then
            Error "Tape device in BACKUP_URL '$BACKUP_URL' and TAPE_DEVICE '$TAPE_DEVICE' is not the same"
        fi

        if [[ -z "$TAPE_DEVICE" ]] ; then
            TAPE_DEVICE=$testdevice
        fi
    fi
fi

if [[ -z "$BACKUP_URL" ]]; then
    if [[ "$TAPE_DEVICE" ]] ; then
        BACKUP_URL="tape://$TAPE_DEVICE"
    fi
fi

if [[ -z "$OUTPUT_URL" ]]; then
    if [[ "$TAPE_DEVICE" ]] ; then
        OUTPUT_URL="tape://$TAPE_DEVICE"
    fi
fi

if [[ "$TAPE_DEVICE" ]]; then
    Log "Tape device $TAPE_DEVICE selected."
fi
