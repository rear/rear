# 450_start_coh_agent.sh
# Start the Cohesity agent inside the rescue/recovery system so that the
# Cohesity cluster can reach it to perform the actual data restore.

COH_AGENT_WRAPPER=/opt/cohesity/agent/software/crux/bin/cohesity_linux_agent.sh

if has_binary systemctl && systemctl list-unit-files cohesity-agent.service &>/dev/null ; then
    systemctl start cohesity-agent
    StopIfError $? "Unable to start the cohesity-agent systemd service"
else
    test -x "$COH_AGENT_WRAPPER" || Error "Cannot execute $COH_AGENT_WRAPPER to start the Cohesity agent"
    "$COH_AGENT_WRAPPER" start
    StopIfError $? "Unable to start the Cohesity agent via $COH_AGENT_WRAPPER"
fi

LogPrint "Cohesity agent started."
