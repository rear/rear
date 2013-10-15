# 40_verify_nsr.sh
# read NSR server name from /nsr/res/servers file of /var/lib/rear/recovery/nsr_server

if [[ ! -z "$NSRSERVER" ]]; then
    Log "NSRSERVER ($NSRSERVER) was defined in $CONFIG_DIR/local.conf"
elif [[ -f $VAR_DIR/recovery/nsr_server ]]; then
    NSRSERVER=$( cat $VAR_DIR/recovery/nsr_server )
else
    Error "Could not retrieve the EMC NetWorker Server name. Define NSRSERVER in $CONFIG_DIR/local.conf file"
fi

# check that nsr server is actually available (ping)
test "${NSRSERVER}" || Error "Define NSRSERVER (hostname or IP address) in $CONFIG_DIR/local.conf file"

if test "$PING" ; then
        if ping -c 1 "${NSRSERVER}" >/dev/null 2>&1 ; then
           Log "EMC NetWorker Server ${NSRSERVER} seems to be up and running."
        else
           Error "Sorry, but cannot reach EMC NetWorker Server ${NSRSERVER}"
        fi
else
        Log "Skipping ping test"
fi

Log "EMC NetWorker server NSRSERVER=$NSRSERVER"
