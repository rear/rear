# 450_check_dp_client_configured.sh
# this script has a simple goal: check if this client system has been properly
# configured on the Cell Manager and backed up at least once - no more no less

OMNIDB=/opt/omni/bin/omnidb
OMNIR=/opt/omni/bin/omnir
VBDA=/opt/omni/lbin/vbda

Log "Backup method is DP: check Data Protector requirements"
test -x $VBDA || Error "Cannot execute $VBDA
Install Data Protector Disk Agent (DA component) on the client."

test -x $OMNIR || Error "Cannot execute $OMNIR
Install Data Protector User Interface (CC component) on the client."

$OMNIDB -filesystem | grep $( hostname ) || Error "Data Protector check failed, error code $?.
Check if the user root is configured in Data Protector UserList and if backups for this client exist in the IDB.
See $RUNTIME_LOGFILE for more details."
