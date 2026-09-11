# 430_check_coh_agent_identity.sh
# Warn if this recovery host's IP address differs from what the Cohesity agent
# had registered with the cluster, since /etc/cohesity-agent/agent.cfg bakes in
# the original IP address(es), hostname, and registered cluster ID.

COH_AGENT_CFG=/etc/cohesity-agent/agent.cfg

if ! test -s "$COH_AGENT_CFG" ; then
    LogPrint "Cohesity agent config $COH_AGENT_CFG not found, skipping identity check."
    return 0
fi

LogPrint ""
LogPrint "Current IP addresses on this system:"
LogPrint "$( ip addr | grep inet | cut -d / -f 1 | grep -v 127.0.0.1 | grep -v ::1 )"
LogPrint ""

local prompt="Does this recovery host have the same IP address as the original system?"
local answer=""
while true ; do
    # the default (i.e. the automated response after the timeout) should be 'yes':
    answer="$( UserInput -I COH_SAME_AGENT_IP -p "$prompt" -D 'yes' )"
    if is_true "$answer" ; then
        LogPrint "Assuming the Cohesity agent identity (IP/hostname) is unchanged."
        return 0
    fi
    if is_false "$answer" ; then
        break
    fi
    UserOutput "Please answer 'yes' or 'no'"
done

LogPrint "
The IP address of this recovery host differs from what is registered in
$COH_AGENT_CFG for the Cohesity cluster this agent was originally registered with.
After 'rear recover' completes you will likely need to re-register this agent
with the Cohesity cluster (from the Cohesity Data Cloud console or via its REST
API) before further backups/restores of this host will work correctly.
"
