# Check that bareos is installed and configured
#
# are all  the files/directories present?

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacule restore using bextract, no need for a director
   return
fi

# Check bconsole version and use appropriate CLI switch
BCONSOLE_VERSION=$(bconsole --version | awk -F '.' '{print $1}')
if [ "$BCONSOLE_VERSION" -ge 22 ]; then
	BCONSOLE_XC="--xc"
else
	BCONSOLE_XC="-xc"
fi

#
# See if we can ping the director
#
# is the director server present? Fetch from /etc/bareos/bconsole.conf file
BAREOS_DIRECTOR=$(bconsole "$BCONSOLE_XC" | grep -i address | awk '{ print $3 }')
[ "${BAREOS_DIRECTOR}" ]
StopIfError "Director not configured in bconsole"

if test "$PING"; then
	ping -c 2 -q  $BAREOS_DIRECTOR >/dev/null
	StopIfError "Backup host [$BAREOS_DIRECTOR] not reachable."
else
	Log "Skipping ping test"
fi

# does the director allow connections from this client? bconsole knows!
#
# We want these two lines to show that we can connect to the director
# and that the director can connect to the file daemon on this system.
# "Connecting to Director 'director_name-fd:9101'"
# "Connecting to Client 'bareos_client_name-fd at FQDN:9102"
if [ -z "$BAREOS_CLIENT" ]
then
   BAREOS_CLIENT="$HOSTNAME-fd"
fi

BAREOS_RESULT=( `echo -e " status client=${BAREOS_CLIENT}" | bconsole |grep Connect ` )

director=${BAREOS_RESULT[3]}
client=${BAREOS_RESULT[9]}

[ "$director" ]
StopIfError "Bareos director not reachable."

[ "$client" ]
StopIfError "Bareos client status unknown on director."

Log "Bareos director = $director, client = $client"
