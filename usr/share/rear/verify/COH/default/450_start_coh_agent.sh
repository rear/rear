# 450_start_coh_agent.sh

# Start the Cohesity agent inside the rescue/recovery system so that the
# Cohesity cluster can reach it to perform the actual data restore.

local coh_agent_wrapper=/opt/cohesity/agent/software/crux/bin/cohesity_linux_agent.sh

# check the unit file on disk, not list-unit-files' exit code (always 0 on systemd 219/RHEL7)
if has_binary systemctl \
    && { test -e /etc/systemd/system/cohesity-agent.service || test -e /usr/lib/systemd/system/cohesity-agent.service ; } ; then
    systemctl start cohesity-agent || Error "Unable to start the cohesity-agent systemd service"
else
    test -x "$coh_agent_wrapper" || Error "Cannot execute $coh_agent_wrapper to start the Cohesity agent"
    "$coh_agent_wrapper" start || Error "Unable to start the Cohesity agent via $coh_agent_wrapper"
fi

LogPrint "Cohesity agent started."
