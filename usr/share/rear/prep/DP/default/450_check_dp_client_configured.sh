# 450_check_dp_client_configured.sh
# this script has a simple goal: check if this client system has been properly
# defined on the DP cell server and that a backup specification has been
# made for this client - no more no less

OMNIDB=/opt/omni/bin/omnidb
OMNIR=/opt/omni/bin/omnir

Log "Backup method is DP: check Data Protector requirements"
[ -x ${OMNIR} ]
StopIfError "Please install Data Protector User Interface (cc component) on the client."

${OMNIDB} -filesystem | grep $(hostname) >/dev/null
StopIfError "Data Protector check failed with error code $? (no filesystem backup found).
See $RUNTIME_LOGFILE for more details."
