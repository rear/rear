#
# Check that bareos is installed and configuration files exist

LogPrint "Bareos: checking requirements ..."

# First determine whether we need to restore using bconsole or bextract.

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   if [ -z "$BEXTRACT_VOLUME" ]; then
      BEXTRACT_VOLUME=*
   fi

   [ -x /usr/sbin/bextract ]
   StopIfError "Bareos executable (bextract) missing or not executable"

   bareos-sd -t 
   StopIfError "Bareos-sd configuration invalid"

else

    ### Bareos support using bconsole

    if ! has_binary bareos-fd; then
        Error "Bareos executable (bareos-fd) missing or not executable"
    fi

    if ! bareos-fd -t; then
        Error "bareos-fd: configuration invalid"
    fi

    if ! systemctl --quiet is-active bareos-fd.service; then
        Log "$(systemctl status bareos-fd.service)"
        Error "bareos-fd.service is not running"
    fi

    while ! systemctl --quiet is-active bareos-fd.service; do 
        ((count > 3)) && Error "Failed to start bareos-fd.service, giving up." 
        let count++ 
        LogPrint "bareos-fd not running, trying to start (attempt $count)" 
        systemctl --quiet is-active bareos-fd.service
        sleep 3 
    done    
    
    if ! has_binary bconsole; then
        Error "Bareos executable (bconsole) missing or not executable"
    fi

    if ! bconsole -t; then
        Error "Bareos bconsole configuration invalid"
    fi

    bcommand_check_client_status "$BAREOS_CLIENT"
fi
