# 450_check_dp_client_configured.sh
# this script has a simple goal: check if this client system has been properly
# defined on the DP cell server and that a backup specification has been
# made for this client - no more no less

Log "Backup method is DP: check Data Protector 6.* requirements"
[ -x /opt/omni/bin/omnir ]
StopIfError "Please install Data Protector 6 User Interface component."

/opt/omni/bin/omnidb -filesystem | grep $(hostname) >/dev/null
StopIfError "Data Protector check failed with error code $? (no filesystem backup found).
See $RUNTIME_LOGFILE for more details."
