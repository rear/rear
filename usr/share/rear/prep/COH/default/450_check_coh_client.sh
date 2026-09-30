# 450_check_coh_client.sh
# Check that the Cohesity agent is installed and running on this client

local coh_agent_exec=/opt/cohesity/agent/software/crux/bin/linux_agent_exec

Log "Backup method is COH: check Cohesity agent requirements"

test -x "$coh_agent_exec" || Error "Cannot execute $coh_agent_exec
Install the Cohesity agent on this client and register it with a Cohesity cluster."

pgrep -f "$coh_agent_exec" >/dev/null || Error "Cohesity agent ($coh_agent_exec) is not running on this client."
