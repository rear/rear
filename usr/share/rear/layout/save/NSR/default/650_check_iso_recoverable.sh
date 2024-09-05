# 650_check_iso_recoverable.sh

# In case NSR_CLIENT_MODE is enabled return else continue ...
if is_true "$NSR_CLIENT_MODE"; then
    return
fi

# This check for Networker ISO Backups was implemented
# via https://github.com/rear/rear/issues/653
# In ReaR 3.0 this check is deprecated
# see https://github.com/rear/rear/issues/3069#issuecomment-1808121160
# and https://github.com/rear/rear/pull/3077#issuecomment-1807828407
# This check contradicts how "rear checklayout" is meant to be used
# because this check implements that the checklayout workflow
# is enhanced to also check the backup so it mixes up
# checking the disk layout (what "rear checklayout" is meant to do)
# with checking the backup (what "rear checklayout" is not meant to do)
# see https://github.com/rear/rear/pull/3077#issuecomment-1807891301
# As a consequence this check always results exit code 1 (at least in some cases)
# for "rear checklayout" even if nothing of the disk layout had changed
# see https://github.com/rear/rear/issues/3069
ErrorIfDeprecated nsr_check_iso_recoverable "Check for Networker Backups conflicts with 'rear checklayout'"
    
CLIENTNAME=$(hostname)

OBJECTS=$( nsrinfo -s ${NSRSERVER} -N ${ISO_DIR}/${ISO_PREFIX}.iso ${CLIENTNAME} | \
           awk '/objects found/ { print $1; }' )

if [[ ${OBJECTS} -eq 0 ]]; then
   LogPrint "No Networker ISO Backups found."
   EXIT_CODE=1
else
   LogPrint "${OBJECTS} Networker ISO Backups found."
fi
