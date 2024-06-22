#
# Check that bareos configuration files exist

if [ "$BAREOS_RESTORE_MODE" = "bextract" ]; then

    if ! bareos-sd -t; then
        Error "Bareos-sd configuration invalid"
    fi

else

    ### Bareos support using bconsole
    if ! bareos-fd -t; then
        Error "Bareos-fd configuration invalid"
    fi

    if ! systemctl status bareos-fd.service; then
        Error "bareos-fd service is not running"
    fi

    if ! bconsole -t; then
        Error "Bareos bconsole invalid"
    fi

fi
