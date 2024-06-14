#
# mount backup device
#

if [ "$BAREOS_RESTORE_MODE" != "bextract" ]; then
    return
fi

### Bareos support using bextract
if [ -b "$BEXTRACT_DEVICE" ]; then
    mkdir -p /backup
    if ! mount "$BEXTRACT_DEVICE" /backup; then
        Error "Could not mount Bareos device $BAREOS_DEVICE at /backup"
    fi
fi
