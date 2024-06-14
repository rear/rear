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

    if ! systemctl --quiet is-active bareos-fd.service; then
        Log "$(systemctl status bareos-fd.service)"
        Error "bareos-fd.service is not running"
    fi

    while ! systemctl is-active bareos-fd.service; do
        ((count > 3)) && Error "Failed to start bareos-fd.service, giving up."
        (( count++ ))
        LogPrint "bareos-fd not running, trying to start (attempt $count)"
        systemctl start bareos-fd.service
        sleep 3
    done    

    if ! bconsole -t; then
        Error "Bareos bconsole configuration invalid"
    fi

    # status is good or it errors out
    bcommand_check_client_status "$BAREOS_CLIENT"
fi
