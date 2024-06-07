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

    if ! has_binary bconsole; then
        Error "Bareos executable (bconsole) missing or not executable"
    fi

    if ! bconsole -t; then
        Error "Bareos bconsole configuration invalid"
    fi

    LogPrint "Connecting to the Bareos Director ..."
    local bconsole_client_status=$(bconsole <<< "status client=$BAREOS_CLIENT")
    local rc=$?
    Log "${bconsole_client_status}"
    if [ $rc -ne 0 ]; then
        Error "Failed to connect to Bareos Director."
    fi
    LogPrint "Connecting to the Bareos Director: OK"

    if ! grep "Connecting to Client $BAREOS_CLIENT" <<< "${bconsole_client_status}"; then
        Error "Failure: The Bareos Director cannot connect to the local filedaemon ($BAREOS_CLIENT)."
    fi

    if ! grep "Running Jobs:" <<< "${bconsole_client_status}"; then
        Error "Failure: The Bareos Director cannot connect to the local filedaemon ($BAREOS_CLIENT)."
    fi

    LogPrint "Bareos Director: can connect to the local filedaemon ($BAREOS_CLIENT)."

fi
