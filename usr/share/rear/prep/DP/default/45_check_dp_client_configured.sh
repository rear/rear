# 45_check_dp_client_configured.sh
# this script has a simple goal: check if this client system has been properly
# defined on the DP cell server and that a backup specification has been
# made for this client - no more no less

Log "Backup method is DP: check Data Protector 6.* requirements"
[ ! -x /opt/omni/bin/omnir ] && Error "Please install Data Protector 6 User Interface component."

/opt/omni/bin/omnidb -filesystem | grep $(hostname) 1>&8 
ProgressStopIfError $? "Data Protector check failed with error code $? (no filesystem backup found).
See /tmp/rear.log for more details."
