# 400_verify_veeam.sh
# check that veeam vbrserver is actually reachable on port 10006
test "${VEEAM_SERVER_HOSTNAME}" || Error "Define VEEAM_SERVER_HOSTNAME (hostname or IP address)"

if nc -w 3 -z "$VEEAM_SERVER_HOSTNAME" 10006; then
    LogPrint "Veeam VBR Server: '$VEEAM_SERVER_HOSTNAME' seems to be up and running."
else
    Error "Unable to contact Veeam VBR Server: '$VEEAM_SERVER_HOSTNAME' on port 10006"
fi

# Veeam linux client agent registration

Log "Deleting Veeam SQLite Linux Agent Database"
rm -rf $v /var/lib/veeam/*

# check linux distribution and change the veeamservice systemd unit file for correct startup
if ( egrep -q "Debian|Ubuntu" /etc/os-release ) ;
    then sed -i 's/\/var//g' /usr/lib/systemd/system/veeamservice.service
    else Error
fi

LogPrint "Starting veeamservice agent for linux"
systemctl start veeamservice || Error "Failed to start veeamservice Agent for Linux"

Log "Accept Veeam EULA agreement"
# create directories for EULA agreement
mkdir -p $v /usr/share/doc/veeam/
touch $v /usr/share/doc/veeam/EULA
touch $v /usr/share/doc/veeam/3rdPartyNotices.txt

Log "Query available Veeam VBR Server to trigger license agreement"
yes yes | veeamconfig vbrServer list 1>/dev/null || Error "Unable to query a Veeam VBR server"

LogPrint "Registering Veeam linux client agent to Veeam VBR backup server"
if test "$VEEAM_USER" && { test "$VEEAM_PASSWORD"; } 2>>/dev/$SECRET_OUTPUT_DEV; then
    if { veeamconfig vbrServer add --name "$VEEAM_SERVER_HOSTNAME" --address "$VEEAM_IPADDR" --domain "$VEEAM_DOMAIN" --login "$VEEAM_USER" --password "$VEEAM_PASSWORD"; } 2>>/dev/$SECRET_OUTPUT_DEV; then
        LogPrint "Veeam linux client agent registered successfully to veeam VBR server: '$VEEAM_SERVER_HOSTNAME'"
    else
        Error "Veeam linux client agent registration failed as '$VEEAM_DOMAIN\\$VEEAM_USER' at '$VEEAM_SERVER_HOSTNAME' ($VEEAM_IPADDR) failed"
    fi
fi
