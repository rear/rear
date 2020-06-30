# 400_verify_dp.sh
# read Data Protector vars from config file

CELL_SERVER="`cat /etc/opt/omni/client/cell_server`"

# check that cell server is actually available (ping)
[ "${CELL_SERVER}" ]
StopIfError "Data Protector Cell Manager not set in /etc/opt/omni/client/cell_server (TCPSERVERADDRESS) !"

if test "$PING" ; then
	ping -c 1 "${CELL_SERVER}" >/dev/null 2>&1
	StopIfError "Data Protector Cell Manager ${CELL_SERVER} not responding to ping."

	Log "Data Protector Cell Manager ${CELL_SERVER} seems to be reachable."
else
	Log "Skipping ping test"
fi

