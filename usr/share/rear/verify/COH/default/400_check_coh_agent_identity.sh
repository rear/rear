# 400_check_coh_agent_identity.sh

# Compare the hostname registered in the agent config with the current
# hostname. On a mismatch the agent identity must be reset
# for this recovery session. On a match the operator can still reset it
# if wanted. The original agent registration is not touched, so it stays
# valid after the restored system boots.

local coh_agent_cfg=/etc/cohesity-agent/agent.cfg
local coh_agent_server_cert=/etc/cohesity-agent/server_cert
local coh_agent_hostuuid=/var/cohesity/telemetry/hostuuid
local cfg_hostname current_hostname
local prompt answer reset_prompt reset_answer

# Tell finalize/COH/default/900_copy_coh_agent_identity.sh whether the identity was reset:
COH_AGENT_IDENTITY_RESET=false

if ! test -s "$coh_agent_cfg" ; then
    LogPrint "Cohesity agent config $coh_agent_cfg not found, skipping identity check."
    return 0
fi

function coh_reset_agent_identity () {
    COH_AGENT_IDENTITY_RESET=true
    if has_binary systemctl && systemctl is-active --quiet cohesity-agent ; then
        LogPrint "Stopping cohesity-agent before resetting its identity..."
        systemctl stop cohesity-agent || Error "Unable to stop the cohesity-agent systemd service"
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
job when instructed. This new identity is only used during the recovery. If the
recovered system keeps the same hostname it is copied to the recovered system after
the restore, otherwise the original identity comes back with the restore. In both
cases no further registration is needed after reboot.
"
}

cfg_hostname="$( sed -n 's/^[[:space:]]*hostname:[[:space:]]*"\([^"]*\)".*/\1/p' "$coh_agent_cfg" | head -n1 )" || Error "Failed to read hostname from $coh_agent_cfg"

current_hostname="$( hostname )" || Error "Failed to determine current hostname"

LogPrint ""
LogPrint "Registered Cohesity agent hostname:"
LogPrint "${cfg_hostname:-<unknown>}"
LogPrint ""
LogPrint "Current hostname:"
LogPrint "$current_hostname"
LogPrint ""

if test -n "$cfg_hostname" ; then
    if test "${current_hostname,,}" != "${cfg_hostname,,}" ; then
        LogPrint "
Detected: hostname differs from what is registered in
$coh_agent_cfg. Resetting the Cohesity agent identity for this recovery
session is required.
"
        coh_reset_agent_identity
        return 0
    fi
    LogPrint "Detected: hostname matches the registered Cohesity agent identity."
else
    LogPrint "Could not automatically verify hostname against $coh_agent_cfg."
    prompt="Does this recovery host have the same hostname as the original system?"
    answer=""
    while true ; do
        answer="$( UserInput -I COH_SAME_AGENT_IP -p "$prompt" -D 'yes' )"
        if is_true "$answer" ; then
            break
        fi
        if is_false "$answer" ; then
            coh_reset_agent_identity
            return 0
        fi
        UserOutput "Answer 'yes' or 'no'"
    done
fi

reset_prompt="Reset the Cohesity agent identity anyway (e.g. if the original agent registration is lost or invalid)?"
reset_answer=""
while true ; do
    reset_answer="$( UserInput -I COH_RESET_AGENT_IDENTITY -p "$reset_prompt" -D 'no' )"
    if is_true "$reset_answer" ; then
        coh_reset_agent_identity
        return 0
    fi
    if is_false "$reset_answer" ; then
        LogPrint "Keeping the existing Cohesity agent identity. The restore brings back the original identity, no registration is needed after reboot."
        return 0
    fi
    UserOutput "Answer 'yes' or 'no'"
done
