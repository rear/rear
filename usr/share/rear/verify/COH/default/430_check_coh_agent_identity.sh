# 430_check_coh_agent_identity.sh
# Compares agent.cfg's registered hostname/IP against the current system.
# On a mismatch the agent identity is reset (mandatory); on a match it can
# still be reset optionally. Renaming (not deleting) is non-destructive: the
# original server's own agent registration is untouched either way.

COH_AGENT_CFG=/etc/cohesity-agent/agent.cfg
COH_AGENT_SERVER_CERT=/etc/cohesity-agent/server_cert
COH_AGENT_HOSTUUID=/var/cohesity/telemetry/hostuuid

if ! test -s "$COH_AGENT_CFG" ; then
    LogPrint "Cohesity agent config $COH_AGENT_CFG not found, skipping identity check."
    return 0
fi

function coh_reset_agent_identity () {
    if has_binary systemctl && systemctl is-active --quiet cohesity-agent ; then
        LogPrint "Stopping cohesity-agent before resetting its identity..."
        systemctl stop cohesity-agent
        StopIfError $? "Unable to stop the cohesity-agent systemd service"
    fi

    local f=""
    for f in "$COH_AGENT_CFG" "$COH_AGENT_SERVER_CERT" "$COH_AGENT_HOSTUUID" ; do
        if test -e "$f" ; then
            mv -f "$f" "${f}_rear" || LogPrintError "Failed to rename $f to ${f}_rear"
        fi
    done

    LogPrint "
The Cohesity agent identity has been reset. This rescue system will come up
as a fresh, temporary Cohesity agent. Register it with the Cohesity cluster
and run a Physical Server File & Folder recovery job to restore the data onto
it. The original server's own agent registration/identity is untouched and
does not need to be re-registered.
"
}

local cfg_hostname="$( sed -n 's/^[[:space:]]*hostname:[[:space:]]*"\([^"]*\)".*/\1/p' "$COH_AGENT_CFG" | head -n1 )"
local cfg_ipaddrs="$( sed -n 's/^[[:space:]]*ip_addr:[[:space:]]*"\([^"]*\)".*/\1/p' "$COH_AGENT_CFG" )"
local cfg_ipaddrs_global="$( echo "$cfg_ipaddrs" | grep -vi '^fe80:' | grep -v '^169\.254\.' )"

local current_hostname="$( hostname -f 2>/dev/null || hostname )"
local current_ips="$( ip -o addr show | awk '{print $4}' | cut -d / -f 1 | grep -vE '^(127\.0\.0\.1|::1)$' )"
local current_ips_global="$( echo "$current_ips" | grep -vi '^fe80:' | grep -v '^169\.254\.' )"

LogPrint ""
LogPrint "Registered Cohesity agent hostname: ${cfg_hostname:-<unknown>}"
LogPrint "Registered Cohesity agent IP address(es): ${cfg_ipaddrs_global:-<none>}"
LogPrint ""
LogPrint "Current hostname: $current_hostname"
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
$COH_AGENT_CFG. Resetting the Cohesity agent identity for this recovery
session is required.
"
        coh_reset_agent_identity
        return 0
    fi
    LogPrint "Detected: hostname and IP address both match the registered Cohesity agent identity."
else
    LogPrint "Could not automatically verify hostname/IP against $COH_AGENT_CFG."
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

local reset_prompt="Reset the Cohesity agent identity anyway (e.g. if the original client-server registration is lost or invalid)?"
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
