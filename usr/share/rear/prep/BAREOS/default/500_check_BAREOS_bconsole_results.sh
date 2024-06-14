# Check that Bareos is installed and configured
#

if [ "$BAREOS_RESTORE_MODE" != "bconsole" ]; then
   ### restore using bextract, no need for a director
   return
fi

mapfile -t clients < <( bcommand ".clients" )

if (( ${#clients[@]} == 0 )); then
    Error "No Bareos clients found"
fi

if [ "$BAREOS_CLIENT" ]; then
    LogPrint "Using $BAREOS_CLIENT as BAREOS_CLIENT"
    if ! IsInArray "$BAREOS_CLIENT" "${clients[@]}"; then
        Error "Bareos Client ($BAREOS_CLIENT) is not available. Available clients:" "${clients[@]}"
    fi
    return
fi

local userinput_default
if (( ${#clients[@]} == 1 )); then
    userinput_default="-D ${clients[0]}"
elif IsInArray "$HOSTNAME-fd" "${clients[@]}"; then
    userinput_default="-D $HOSTNAME-fd"
fi

until IsInArray "$BAREOS_CLIENT" "${clients[@]}" ; do
    BAREOS_CLIENT="$( UserInput -I BAREOS_CLIENT $userinput_default -p "Choose this host as Bareos Client: " "${clients[@]}" )"
done

# bareos_ensure_client_is_available exists on error.
bareos_ensure_client_is_available "$BAREOS_CLIENT"
echo "BAREOS_CLIENT=$BAREOS_CLIENT" >> "$VAR_DIR/bareos.conf"
