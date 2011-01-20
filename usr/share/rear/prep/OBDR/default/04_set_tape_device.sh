# Extract the tape device from ISO_URL or NETFS_URL
# Either variable can be used, but if both are, they must be the same value

TAPE_DEVICE=

# First, test ISO_URL
if [ "$ISO_URL" ]; then
    scheme="${ISO_URL%%://*}"
    case "$scheme" in
        (tape|obdr) TAPE_DEVICE="${ISO_URL##*://}";;
    esac
fi

# Then, test NETFS_URL
if [ "$NETFS_URL" ]; then
    scheme="${NETFS_URL%%://*}"
    case "$scheme" in
        (tape|obdr)
            tempdevice="${NETFS_URL##*://}"
            # Complain when both are specified, but don't match
            if [ "$TAPE_DEVICE" -a "$TAPE_DEVICE" != "$tempdevice" ]; then
                Error "Tape device in $NETFS_URL and $ISO_URL is not the same"
            fi
            TAPE_DEVICE="$tempdevice"
            ;;
    esac
fi

if [ "$TAPE_DEVICE" ]; then
    Log "Tape device $TAPE_DEVICE selected."
fi
