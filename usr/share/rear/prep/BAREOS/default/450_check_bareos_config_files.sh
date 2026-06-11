#
# Check local Bareos configuration
#

if ! bareos-fd -t; then
    Error "bareos-fd configuration invalid"
fi

if ! systemctl status bareos-fd.service; then
    Error "bareos-fd service is not running"
fi

if ! bconsole -t; then
    Error "Bareos bconsole configuration invalid"
fi

