# Check that Bareos is installed and configured
#

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then
   ### restore using bextract, no need for a director
   return
fi

# Does the director allow connections from this client? bconsole knows!
#
# We want these two lines to show that we can connect to the director
# and that the director can connect to the file daemon on this system.
# "Connecting to Director 'director_name-fd:9101'"
# "Connecting to Client 'bareos_client_name-fd at FQDN:9102"
if [ -z "$BAREOS_CLIENT" ]; then
   BAREOS_CLIENT="$HOSTNAME-fd"
   echo "BAREOS_CLIENT=$BAREOS_CLIENT" >> $VAR_DIR/bareos.conf
fi

bcommand_check_client_status "$BAREOS_CLIENT"
