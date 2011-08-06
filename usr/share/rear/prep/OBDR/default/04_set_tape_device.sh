### Extract the tape device from BACKUP_URL
###

### Either variable can be used, but if both are, they must be the same value

TAPE_DEVICE=${TAPE_DEVICE//\/st/\/nst}

if [[ "$BACKUP_URL" ]]; then
    scheme="${BACKUP_URL%%://*}"
    case "$scheme" in
        (tape)
            tempdevice="${BACKUP_URL##*://}"
            ### Complain when both are specified, but don't match
            if [[ "$TAPE_DEVICE" && "$TAPE_DEVICE" != "$tempdevice" ]]; then
                Error "Tape device in BACKUP_URL '$BACKUP_URL' and TAPE_DEVICE '$TAPE_DEVICE' is not the same"
            fi
            TAPE_DEVICE="$tempdevice"
            ;;
    esac
fi

if [[ "$TAPE_DEVICE" ]]; then
    Log "Tape device $TAPE_DEVICE selected."
fi
