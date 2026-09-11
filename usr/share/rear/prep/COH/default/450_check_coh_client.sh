# 450_check_coh_client.sh
# Check that the Cohesity agent is installed and running on this client

COH_AGENT_EXEC=/opt/cohesity/agent/software/crux/bin/linux_agent_exec

Log "Backup method is COH: check Cohesity agent requirements"

test -x "$COH_AGENT_EXEC" || Error "Cannot execute $COH_AGENT_EXEC
Install the Cohesity agent on this client and register it with a Cohesity cluster."

pgrep -f "$COH_AGENT_EXEC" >/dev/null
StopIfError $? "Cohesity agent ($COH_AGENT_EXEC) is not running on this client."
