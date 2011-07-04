#
# start galaxy daemons and check that they run and connect to the backup server
#
#
/opt/galaxy/Base/Galaxy start
if /opt/galaxy/Base/Galaxy list | grep -q N/A ; then
	Error "Galaxy daemon did not start. Please check with '/opt/galaxy/Base/Galaxy list'"
fi

if test "$GALAXY_COMMCELL" ; then
	if test "$PING" ; then
		ping -c 5 -q "$GALAXY_COMMCELL" >&2 ||\
			Error "Backup server [$GALAXY_COMMCELL] not reachable !"
	else
		Log "Skipping ping test"
	fi
else
	Error "GALAXY_COMMCELL not set !"
fi
