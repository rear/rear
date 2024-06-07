# Check that bareos is installed and configured
#
# are all  the files/directories present?

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then
   ### restore using bextract, no need for a director
   return
fi

if [ "$PING" ]; then

    if [ -z $BAREOS_DIRECTOR_ADDRESS ]; then
        # Check bconsole version and use appropriate CLI switch:
        # Bareos 22 introduced a breaking change how its CLI tools (such as bconsole) parse the arguments.
        # Before it was "bconsole -xc" but since Bareos 22 it must be "bconsole --xc"
        # (otherwise it terminates with exit code 113 so "rear mkrescue" will fail).
        # "bconsole --version" has also been introduced in Bareos 22,
        # therefore if this command succeeds, we use "--xc".
        # The backward compatible fallback is "bconsole -xc".
        # See https://github.com/rear/rear/issues/2900
        BCONSOLE_XC="-xc"
        if bconsole --version >/dev/null 2>&1; then
            BCONSOLE_XC="--xc"
        fi

        #
        # See if we can ping the director
        #
        # is the director server present? Fetch address from configuration.
        BAREOS_DIRECTOR_ADDRESS=$(bconsole "$BCONSOLE_XC" | sed -n -r  's/ *address *= *["](.*)["]/\1/ip')
        [ "${BAREOS_DIRECTOR_ADDRESS}" ]
        StopIfError "Failed to get Bareos Director address via bconsole configuration. Please configure BAREOS_DIRECTOR_ADDRESS."
    fi

    ping -c 2 -q  $BAREOS_DIRECTOR_ADDRESS >/dev/null
    StopIfError "Backup host [$BAREOS_DIRECTOR_ADDRESS] not reachable."
    LogPrint "Backup host [$BAREOS_DIRECTOR_ADDRESS] is reachable."

else
    Log "Skipping ping test"
fi

# does the director allow connections from this client? bconsole knows!
#
# We want these two lines to show that we can connect to the director
# and that the director can connect to the file daemon on this system.
# "Connecting to Director 'director_name-fd:9101'"
# "Connecting to Client 'bareos_client_name-fd at FQDN:9102"
if [ -z "$BAREOS_CLIENT" ]; then
   BAREOS_CLIENT="$HOSTNAME-fd"
   echo "BAREOS_CLIENT=$BAREOS_CLIENT" >> $VAR_DIR/bareos.conf
fi

BAREOS_RESULT=( $(echo -e "status client=${BAREOS_CLIENT}" | bconsole | grep Connect) )
director=${BAREOS_RESULT[3]}
client=${BAREOS_RESULT[9]}

[ "$director" ]
StopIfError "Bareos director not reachable."

[ "$client" ]
StopIfError "Bareos client status unknown on director."

Log "Bareos director = $director, client = $client"
