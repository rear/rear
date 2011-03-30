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
# is the director server present? Fetch from /etc/bacula/bconsole.conf file
BACULA_DIRECTOR=$(grep -i address /etc/bacula/bconsole.conf | awk '{ print $3 }')
[ -z "${BACULA_DIRECTOR}" ] && ProgressStopIfError 1 "Director not defined in /etc/bacula/bconsole.conf"

if test "$PING"; then
	ping -c 2 -q  $BACULA_DIRECTOR 1>&8
	ProgressStopIfError $? "Backup host [$BACULA_DIRECTOR] not reachable."
else
	Log "Skipping ping test"
fi

# does the director allow connections from this client? bconsole knows!
#
# We want these two lines to show that we can connect to the director
# and that the director can connect to the file daemon on this system.
# "Connecting to Director 'director_name-fd:9101'"
# "Connecting to Client 'bacula_client_name-fd at FQDN:9102"
BACULA_CLIENT=`grep $(hostname -s) /etc/bacula/bacula-fd.conf | grep "\-fd" | awk '{print $3}' | cut -d"-" -f1`
[ -z "${BACULA_CLIENT}" ] && ProgressStopIfError 1 "Client $(hostname -s) not defined in /etc/bacula/bacula-fd.conf"

BACULA_RESULT=( `echo -e " status client=${BACULA_CLIENT}-fd" | bconsole |grep Connect ` )

director=${BACULA_RESULT[3]}
client=${BACULA_RESULT[9]}

if test -z "$director" ; then
	ProgressStopIfError 1 "Bacula director not reachable."
elif test -z "$client" ;  then
	ProgressStopIfError 1 "Bacula client status unknown on director."
else
	Log "Bacula director = $director, client = $client"
fi
