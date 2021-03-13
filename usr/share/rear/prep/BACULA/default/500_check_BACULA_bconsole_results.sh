# Check that bacula is installed and configured
#
# are all  the files/directories present?

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacule restore using bextract, no need for a director
   return
fi

#
# See if we can ping the director
#
# is the director server present? Fetch from $BACULA_CONF_DIR/bconsole.conf file
BACULA_DIRECTOR=$(grep -i address $BACULA_CONF_DIR/bconsole.conf | awk '{ print $3 }')
[ "${BACULA_DIRECTOR}" ] || Error "Director not defined in $BACULA_CONF_DIR/bconsole.conf"

# check if the director is responding?
if has_binary nc; then
   DIRECTOR_RESULT=$(nc -vz "${BACULA_DIRECTOR}" 9101 2>&1 | grep -i connected | wc -l)
   [[ $DIRECTOR_RESULT -eq 0 ]] && Error "Bacula director ${BACULA_DIRECTOR} is not responding."
fi

# does the director allow connections from this client? bconsole knows!
#
# We want these two lines to show that we can connect to the director
# and that the director can connect to the file daemon on this system.
# "Connecting to Director 'director_name-fd:9101'"
# "Connecting to Client 'bacula_client_name-fd at FQDN:9102"
BACULA_CLIENT=$(grep $(hostname -s) $BACULA_CONF_DIR/bacula-fd.conf | grep "\-fd" | awk '{print $3}' | sed -e "s/-fd//g")
[ "${BACULA_CLIENT}" ] || Error "Client $(hostname -s) not defined in $BACULA_CONF_DIR/bacula-fd.conf"

BACULA_RESULT=( $(echo -e " status client=${BACULA_CLIENT}-fd" | bconsole | grep Connect) )

director=${BACULA_RESULT[3]}
client=${BACULA_RESULT[9]}

[ "$director" ] || Error "Bacula director not reachable."

[ "$client" ] || Error "Bacula client status unknown on director."

Log "Bacula director = $director, client = $client"
