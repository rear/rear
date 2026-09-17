# 430_check_coh_agent_identity.sh
# Compares agent.cfg's registered hostname/IP against the current system.
# On a mismatch the agent identity is reset (mandatory). On a match it can
# still be reset optionally. The original agent registration remains untouched
# post restore.

local coh_agent_cfg=/etc/cohesity-agent/agent.cfg
local coh_agent_server_cert=/etc/cohesity-agent/server_cert
local coh_agent_hostuuid=/var/cohesity/telemetry/hostuuid

if ! test -s "$coh_agent_cfg" ; then
    LogPrint "Cohesity agent config $coh_agent_cfg not found, skipping identity check."
    return 0
fi

function coh_reset_agent_identity () {
    if has_binary systemctl && systemctl is-active --quiet cohesity-agent ; then
        LogPrint "Stopping cohesity-agent before resetting its identity..."
        systemctl stop cohesity-agent
        StopIfError $? "Unable to stop the cohesity-agent systemd service"
    fi

    local f=""
    for f in "$coh_agent_cfg" "$coh_agent_server_cert" "$coh_agent_hostuuid" ; do
        if test -e "$f" ; then
            mv -f "$f" "${f}_rear" || LogPrintError "Failed to rename $f to ${f}_rear"
        fi
    done

    LogPrint "
The Cohesity agent identity has been reset in the recovery environment. Register the
new agent with the Cohesity cluster and run a Physical Server File & Folder recovery
job when instructed. The original agent registration/identity remains untouched and
does not need to be re-registered.
"
}

local cfg_hostname cfg_ipaddrs cfg_ipaddrs_global
cfg_hostname="$( sed -n 's/^[[:space:]]*hostname:[[:space:]]*"\([^"]*\)".*/\1/p' "$coh_agent_cfg" | head -n1 )" || Error "Failed to read hostname from $coh_agent_cfg"
cfg_ipaddrs="$( sed -n 's/^[[:space:]]*ip_addr:[[:space:]]*"\([^"]*\)".*/\1/p' "$coh_agent_cfg" )" || Error "Failed to read IP addresses from $coh_agent_cfg"
cfg_ipaddrs_global="$( echo "$cfg_ipaddrs" | grep -vi '^fe80:' | grep -v '^169\.254\.' )" || true

local current_hostname current_ips current_ips_global
current_hostname="$( hostname -f 2>/dev/null || hostname )" || Error "Failed to determine current hostname"
current_ips="$( ip -o addr show | awk '{print $4}' | cut -d / -f 1 | grep -vE '^(127\.0\.0\.1|::1)$' )" || true
current_ips_global="$( echo "$current_ips" | grep -vi '^fe80:' | grep -v '^169\.254\.' )" || true

LogPrint ""
LogPrint "Registered Cohesity agent hostname:"
LogPrint "${cfg_hostname:-<unknown>}"
LogPrint "Registered Cohesity agent IP address(es):"
LogPrint "${cfg_ipaddrs_global:-<none>}"
LogPrint ""
LogPrint "Current hostname:"
LogPrint "$current_hostname"
LogPrint "Current IP addresses on this system:"
LogPrint "$current_ips"
LogPrint ""

if test -n "$cfg_hostname" && test -n "$cfg_ipaddrs_global" ; then
    local hostname_match=false
    local ip_match=false
    if test "$( echo "$current_hostname" | tr 'A-Z' 'a-z' )" = "$( echo "$cfg_hostname" | tr 'A-Z' 'a-z' )" ; then
        hostname_match=true
    fi
    local cfg_ip=""
    while read -r cfg_ip ; do
        test -z "$cfg_ip" && continue
        if echo "$current_ips_global" | grep -qxF "$cfg_ip" ; then
            ip_match=true
            break
        fi
    done <<< "$cfg_ipaddrs_global"

    if ! $hostname_match || ! $ip_match ; then
        LogPrint "
Detected: hostname and/or IP address differ from what is registered in
$coh_agent_cfg. Resetting the Cohesity agent identity for this recovery
session is required.
"
        coh_reset_agent_identity
        return 0
    fi
    LogPrint "Detected: hostname and IP address both match the registered Cohesity agent identity."
else
    LogPrint "Could not automatically verify hostname/IP against $coh_agent_cfg."
    local prompt="Does this recovery host have the same IP address and hostname as the original system?"
    local answer=""
    while true ; do
        answer="$( UserInput -I COH_SAME_AGENT_IP -p "$prompt" -D 'yes' )"
        if is_true "$answer" ; then
            break
        fi
        if is_false "$answer" ; then
            coh_reset_agent_identity
            return 0
        fi
        UserOutput "Please answer 'yes' or 'no'"
    done
fi

local reset_prompt="Reset the Cohesity agent identity anyway (e.g. if the original agent registration is lost or invalid)?"
local reset_answer=""
while true ; do
    reset_answer="$( UserInput -I COH_RESET_AGENT_IDENTITY -p "$reset_prompt" -D 'no' )"
    if is_true "$reset_answer" ; then
        coh_reset_agent_identity
        return 0
    fi
    if is_false "$reset_answer" ; then
        LogPrint "Keeping the existing Cohesity agent identity."
        return 0
    fi
    UserOutput "Please answer 'yes' or 'no'"
done
