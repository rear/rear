# 380_request_client_destination.sh

# Request the user to input the new Client name if the restore is a clone.
# OR Request the user to hit ENTER to do a normal restore to the same client.

# read NBU vars from NBU config file bp.conf
while read KEY VALUE ; do
    echo "$KEY" | grep -qi '^#' && continue
    test -z "$KEY" && continue
    KEY="$( echo "$KEY" | tr '[:lower:]' '[:upper:]' )"
    export NBU_$KEY="$( echo "$VALUE" | sed -e 's/=//' -e 's/ //g' )"
done </usr/openv/netbackup/bp.conf

NBU_CLIENT_SOURCE="${NBU_CLIENT_NAME}"

LogPrint ""
LogPrint "Netbackup Client Source For This Restore is:  $NBU_CLIENT_SOURCE"
LogPrint "If this is a normal restore to the same client press ENTER."
LogPrint "If this is a restore to a CLONE enter the new client name."
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -r -p "Enter Cloned Client name or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8

# validate input
# FIXME: The input is not actually validated here.
# There is only LogPrint that show the input
# but no code that actually validates the input
# so the user cannot retry in case of invalid input
# cf. https://github.com/rear/rear/pull/2257
if test -z "${REPLY}"; then
        LogPrint ""
        LogPrint "Client is the same as Client Source. Normal restore...."
else
        NBU_CLIENT_NAME="${REPLY}"
        LogPrint ""
        LogPrint "NBU CLONE TO CLIENT: ${NBU_CLIENT_NAME}."
        LogPrint "Ensure all servers defined in bp.conf can connect to this RESCUE system using the hostname: ${NBU_CLIENT_NAME}"
        LogPrint "Current RESCUE system IP info:" ; ip addr
        LogPrint ""
        LogPrint "bp.conf defined servers: " ; cat /usr/openv/netbackup/bp.conf | grep -i server
        LogPrint ""
        # Use the original STDIN STDOUT and STDERR when rear was launched by the user
        # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
        # FIXME: Is it right to let 'read' timeout here which makes 'rear recover' automatically proceed after WAIT_SECS?
        # I <jsmeix@suse.de> think at this point during 'rear recover' the user may not yet have been able to
        # "Ensure all servers defined in bp.conf can connect to this RESCUE system using the hostname: ${NBU_CLIENT_NAME}"
        # so a 'rear_shell' call could help here so that he could adapt his /usr/openv/netbackup/bp.conf as needed.
        read -t $WAIT_SECS -r -p "Press any key to continue ... [$WAIT_SECS secs] " 0<&6 1>&7 2>&8
fi

