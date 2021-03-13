# 400_verify_dp.sh
# read Data Protector vars from config file

# the Cell Manager must be configured on the client
# if /etc/opt/omni/client/cell_server exists and contains something, we're good
test -s /etc/opt/omni/client/cell_server || Error "Data Protector Cell Manager not configured in /etc/opt/omni/client/cell_server"
CELL_SERVER="$( cat /etc/opt/omni/client/cell_server )"

OMNICHECK=/opt/omni/bin/omnicheck

if [ $ARCH == "Linux-i386" ] || [ $ARCH == "Linux-ia64" ]; then
    # check that the Cell Manager is responding on the INET port
    ${OMNICHECK} -patches -host ${CELL_SERVER} || Error "Data Protector Cell Manager is not responding, error code $?.
    See $RUNTIME_LOGFILE for more details."
fi
