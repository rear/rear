# 350_start_netbackup.sh

# Start PBX and NetBackup client daemons, trying systemd first, then
# SysV, then xinetd as a fallback for pre-PBX clients. Then enroll a
# host certificate with the Primary server using 'nbcertcmd'. NetBackup
# does not include the original certificate in the backup, so a fresh
# token-based enrollment is required here, since the recovery image
# never carries the original certificate either.

local nbu_vnetd=/usr/openv/netbackup/bin/vnetd
local nbu_bpcd=/usr/openv/netbackup/bin/bpcd
local nbu_nbcertcmd=/usr/openv/netbackup/bin/nbcertcmd

# check the unit file on disk, not list-unit-files' exit code (always 0 on systemd 219/RHEL7)
# restart the systemd services since they start automatically with the rescue system
if has_binary systemctl \
    && { test -e /etc/systemd/system/vxpbx_exchanged.service || test -e /usr/lib/systemd/system/vxpbx_exchanged.service ; } ; then
    systemctl daemon-reload
    systemctl restart vxpbx_exchanged.service || Error "Unable to restart vxpbx_exchanged via systemd."
    if test -e /etc/systemd/system/netbackup.service -o -e /usr/lib/systemd/system/netbackup.service ; then
        systemctl restart netbackup.service || Error "Unable to restart the NetBackup client via systemd."
    fi
elif test -x /etc/init.d/vxpbx_exchanged ; then
    /etc/init.d/vxpbx_exchanged start || Error "Unable to start vxpbx_exchanged via /etc/init.d/vxpbx_exchanged."
    if test -x /etc/init.d/netbackup ; then
        /etc/init.d/netbackup start || Error "Unable to start the NetBackup client via /etc/init.d/netbackup."
    fi
elif test -r /etc/xinetd.d/vnetd -o -r /etc/xinetd.d/bpcd -o -r /etc/xinetd.d/vopied ; then
    xinetd || Error "Unable to start xinetd."
    test -f /etc/xinetd.d/vnetd || "$nbu_vnetd" -standalone
    test -f /etc/xinetd.d/bpcd || "$nbu_bpcd" -standalone
else
    LogPrint "WARNING: no NetBackup startup mechanism (systemd/SysV/xinetd) found in the rescue system."
fi

LogPrint "NetBackup services started."

local current_hostname token cert_output rc

test -n "$NBU_SERVER" || Error "Could not determine the NetBackup Primary server from bp.conf (SERVER=)."

LogPrint ""
LogPrint "Fetching the NetBackup CA certificate from $NBU_SERVER..."
LogPrint "You will be asked to confirm the CA certificate's fingerprint of the NetBackup Primary server."
"$nbu_nbcertcmd" -getCAcertificate -server "$NBU_SERVER" 0<&6 1>&7 2>&8 || Error "Unable to fetch the NetBackup CA certificate from $NBU_SERVER."

test -n "$NBU_CLIENT_CURRENT_HOSTNAME" || Error "Internal error: NBU_CLIENT_CURRENT_HOSTNAME not set by 250_check_nbu_client_name.sh."
current_hostname="$NBU_CLIENT_CURRENT_HOSTNAME"

LogPrint ""
LogPrint "A host certificate may or may not exist on Primary server $NBU_SERVER."
LogPrint "Provide an authorization or reissue token for the client $current_hostname."
LogPrint ""
LogPrint "The token can be created using the NetBackup WebUI or 'nbcertcmd -createtoken' command on the Primary server."

# no timeout: getting a token from the WebUI can take a while. loop until a valid
# token or 'exit' (the escape hatch).
while true ; do
    token=$( UserInput -I NBU_CERT_TOKEN -C -s -r -t 0 -p "Enter NetBackup enrollment token (not displayed as you type):" ) || true
    if test "${token,,}" = "exit" ; then
        Error "NetBackup certificate enrollment cancelled by user."
    fi
    if test -z "$token" ; then
        LogPrintError "A token is required. Cannot restore without a trusted host certificate. Enter a token, or 'exit' to cancel."
        continue
    fi
    cert_output=$( "$nbu_nbcertcmd" -getCertificate -server "$NBU_SERVER" -token "$token" -force 2>&1 )
    rc=$?
    LogPrint ""
    LogPrint "$cert_output"
    test $rc -eq 0 && break
    if echo "$cert_output" | grep -qi "Reissue token is mandatory" ; then
        LogPrintError ""
        LogPrintError "A certificate already exists for this client on $NBU_SERVER. Generate and provide a reissue"
        LogPrintError "token for $current_hostname in the NetBackup WebUI, or 'exit' to cancel."
    else
        LogPrintError "Certificate enrollment failed (see output above). Check the token and try again, or 'exit' to cancel."
    fi
done

LogPrint "NetBackup host certificate enrolled successfully."
