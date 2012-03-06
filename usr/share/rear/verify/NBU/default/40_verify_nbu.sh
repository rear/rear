# 40_verify_nbu.sh

# check that NBU master server is actually available (ping)
[ "${NBU_SERVER}" ]
StopIfError "NBU Master Server not set in bp.conf (TCPSERVERADDRESS) !"

if test "$PING" ; then
	if ping -c 1 "${NBU_SERVER}" >&8 2>&1; then
		Log "NBU Master Server ${NBU_SERVER} seems to be up and running."
	else
		Error "Sorry, but cannot reach NBU Master Server ${NBU_SERVER}"
	fi
else
	Log "Skipping ping test"
fi
