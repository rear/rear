#
# Check Bareos configuration

LogPrint "Bareos: checking requirements ..."

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
