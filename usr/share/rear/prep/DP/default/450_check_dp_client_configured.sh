# 450_check_dp_client_configured.sh
# this script has a simple goal: check if this client system has been properly
# configured on the Cell Manager and backed up at least once - no more no less

OMNIDB=/opt/omni/bin/omnidb
OMNIR=/opt/omni/bin/omnir

Log "Backup method is DP: check Data Protector requirements"
[ -x ${VBDA} ]
StopIfError "Please install Data Protector Disk Agent (DA component) on the client."

[ -x ${OMNIR} ]
StopIfError "Please install Data Protector User Interface (CC component) on the client."

${OMNIDB} -filesystem | grep $(hostname) >/dev/null
StopIfError "Data Protector check failed with error code $?.
Check if root is configured in Data Protector UserList and if backups for this client exist in the IDB.
See $RUNTIME_LOGFILE for more details."
