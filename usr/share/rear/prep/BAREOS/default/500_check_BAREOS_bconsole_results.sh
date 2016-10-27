# Check that bareos is installed and configured
#
# are all  the files/directories present?

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacule restore using bextract, no need for a director
   return
fi

#
# See if we can ping the director
#
# is the director server present? Fetch from /etc/bareos/bconsole.conf file
BAREOS_DIRECTOR=$(grep -i address /etc/bareos/bconsole.conf | awk '{ print $3 }')
[ "${BAREOS_DIRECTOR}" ]
StopIfError "Director not defined in /etc/bareos/bconsole.conf"

if test "$PING"; then
	ping -c 2 -q  $BAREOS_DIRECTOR >&8
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
	BAREOS_CLIENT=`grep $(hostname -s) /etc/bareos/bareos-fd.conf | grep "\-fd" | awk '{print $3}'`
fi
[ "${BAREOS_CLIENT}" ]
StopIfError "Client $(hostname -s) not defined in /etc/bareos/bareos-fd.conf"

BAREOS_RESULT=( `echo -e " status client=${BAREOS_CLIENT}" | bconsole |grep Connect ` )

director=${BAREOS_RESULT[3]}
client=${BAREOS_RESULT[9]}

[ "$director" ]
StopIfError "Bareos director not reachable."

[ "$client" ]
StopIfError 1 "Bareos client status unknown on director."

Log "Bareos director = $director, client = $client"
