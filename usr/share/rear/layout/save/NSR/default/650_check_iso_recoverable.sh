# 650_check_iso_recoverable.sh
#
# In case NSR_CLIENT_MODE is enabled return else continue ...
if is_true "$NSR_CLIENT_MODE"; then
    return
fi

CLIENTNAME=$(hostname)

# read NSR server name from /nsr/res/servers file of /var/lib/rear/recovery/nsr_server
# code snippet taken from verify/NSR/default/400_verify_nsr.sh
# see https://github.com/rear/rear/issues/2162#issuecomment-541343374
# and https://github.com/rear/rear/issues/3069
if [[ ! -z "$NSRSERVER" ]]; then
    Log "NSRSERVER ($NSRSERVER) was defined in $CONFIG_DIR/local.conf"
elif [[ -f $VAR_DIR/recovery/nsr_server ]]; then
    NSRSERVER=$( cat $VAR_DIR/recovery/nsr_server )
else
    Error "Could not retrieve the EMC NetWorker Server name. Define NSRSERVER in $CONFIG_DIR/local.conf file"
fi

OBJECTS=$( nsrinfo -s ${NSRSERVER} -N ${ISO_DIR}/${ISO_PREFIX}.iso ${CLIENTNAME} | \
           awk '/objects found/ { print $1; }' )

if [[ ${OBJECTS} -eq 0 ]]; then
   LogPrint "No Networker ISO Backups found."
   EXIT_CODE=1
else
   LogPrint "${OBJECTS} Networker ISO Backups found."
fi
