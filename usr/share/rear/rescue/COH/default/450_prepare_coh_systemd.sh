# 450_prepare_coh_systemd.sh
# Make sure the cohesity-agent systemd service unit gets included in the rescue image
# (if systemd is used) so 'systemctl start cohesity-agent' works in the rescue system,
# see verify/COH/default/450_start_coh_agent.sh

# Nothing to do when systemd is not used
test -r "/usr/lib/systemd/system/cohesity-agent.service" || return 0

COPY_AS_IS+=( /usr/lib/systemd/system/cohesity-agent.service )
