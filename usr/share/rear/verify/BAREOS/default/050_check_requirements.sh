#
# Check that bareos is configuration exist

LogPrint "Bareos: checking requirements ..."

# First determine whether we need to restore using bconsole or bextract.

if [ "$BAREOS_RESTORE_MODE" = "bextract" ]; then

    ### Bareos support using bextract
    if [ -z "$BEXTRACT_VOLUME" ]; then
        BEXTRACT_VOLUME="*"
    fi

    if ! bareos-sd -t; then
        Error "Bareos-sd configuration invalid"
    fi

else

    ### Bareos support using bconsole

    if ! bareos-fd -t; then
        Error "bareos-fd: configuration invalid"
    fi

    if ! systemctl start bareos-fd.service; then
        Error "Failed to start bareos-fd.service"
    fi

    if ! bconsole -t; then
        Error "Bareos bconsole configuration invalid"
    fi

    # status is good or it errors out
    bareos_ensure_client_is_available "$BAREOS_CLIENT"

fi
