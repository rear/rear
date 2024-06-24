#
# Check that Bareos is installed and configured
#

mapfile -t clients < <( bcommand ".clients" )

if (( ${#clients[@]} == 0 )); then
    Error "No Bareos clients found"
fi

if [ "$BAREOS_CLIENT" ]; then
    if ! IsInArray "$BAREOS_CLIENT" "${clients[@]}"; then
        Error "Bareos Client ($BAREOS_CLIENT) is not available. Available clients:" "${clients[@]}"
    fi
else
    if (( ${#clients[@]} == 1 )); then
        BAREOS_CLIENT="${clients[0]}"
    elif IsInArray "$HOSTNAME-fd" "${clients[@]}"; then
        BAREOS_CLIENT="$HOSTNAME-fd"
    else
        Error "Could not determine this system as Bareos client, no BAREOS_CLIENT specified."
    fi
    {
        echo "# added by prep/BAREOS/default/500_check_bareos_client_configured.sh"
        echo "BAREOS_CLIENT=$BAREOS_CLIENT"
        echo
    } >> "$ROOTFS_DIR/etc/rear/rescue.conf"
fi

# bareos_ensure_client_is_available exists on error.
bareos_ensure_client_is_available "$BAREOS_CLIENT"

LogPrint "Using '$BAREOS_CLIENT' as BAREOS_CLIENT."
