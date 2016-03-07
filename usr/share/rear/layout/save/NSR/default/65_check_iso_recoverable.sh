NSRSERVER=$(cat $VAR_DIR/recovery/nsr_server )
CLIENTNAME=$(hostname)

OBJECTS=$( nsrinfo -s ${NSRSERVER} -N ${ISO_DIR}/${ISO_PREFIX}.iso ${CLIENTNAME} | \
           awk '/objects found/ { print $1; }' )

if [[ ${OBJECTS} -eq 0 ]]; then
   LogPrint "No Networker ISO Backups found."
   EXIT_CODE=1
else
   LogPrint "${OBJECTS} Networker ISO Backups found."
fi
