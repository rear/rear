# 900_copy_coh_agent_identity.sh

# If the Cohesity agent identity was reset in the recovery system, copy the
# new identity (agent.cfg, server_cert, hostuuid) from this rescue system
# onto the recovered disk, so the agent does not need to be registered
# again after the first boot. Only done when the hostname in the restored
# agent.cfg matches the current hostname. If the hostnames differ, the
# recovered system boots back up under a different name than the one the
# new identity was registered with.

if ! is_true "$COH_AGENT_IDENTITY_RESET" ; then
    LogPrint "Cohesity agent identity was not reset. The original identity comes back with the restore, no registration is needed after reboot."
    return 0
fi

local coh_agent_cfg=/etc/cohesity-agent/agent.cfg
local coh_agent_identity_files=( "$coh_agent_cfg" /etc/cohesity-agent/server_cert /var/cohesity/telemetry/hostuuid )
local restored_hostname current_hostname f cp_rc copy_failed=false

if ! test -s "$coh_agent_cfg" ; then
    LogPrint "No new Cohesity agent identity found on this rescue system. Nothing to copy."
    LogPrint "The Cohesity agent on the recovered system may need to be registered again after reboot."
    return 0
fi

if ! test -s "$TARGET_FS_ROOT$coh_agent_cfg" ; then
    LogPrint "No restored $coh_agent_cfg found in $TARGET_FS_ROOT."
    LogPrint "Skipping the Cohesity agent identity copy. The Cohesity agent on the recovered system may need to be registered again after reboot."
    return 0
fi

restored_hostname="$( sed -n 's/^[[:space:]]*hostname:[[:space:]]*"\([^"]*\)".*/\1/p' "$TARGET_FS_ROOT$coh_agent_cfg" | head -n1 )"
if ! current_hostname="$( hostname )" ; then
    LogPrintError "WARNING: Failed to determine the current hostname. Skipping the Cohesity agent identity copy."
    LogPrintError "The Cohesity agent on the recovered system may need to be registered again after reboot."
    return 0
fi

if test "${restored_hostname,,}" != "${current_hostname,,}" ; then
    LogPrint "The hostname in the restored $coh_agent_cfg (${restored_hostname:-<unknown>}) differs from the current hostname ($current_hostname)."
    LogPrint "Skipping the Cohesity agent identity copy. The original identity from the backup is kept, no registration is needed after reboot."
    return 0
fi

# Stop the agent so it does not rewrite its files while they are copied:
if has_binary systemctl && systemctl is-active --quiet cohesity-agent ; then
    LogPrint "Stopping cohesity-agent before copying its identity..."
    systemctl stop cohesity-agent || LogPrintError "Unable to stop the cohesity-agent systemd service"
fi

LogPrint "Copying the new Cohesity agent identity into $TARGET_FS_ROOT ..."
for f in "${coh_agent_identity_files[@]}" ; do
    test -e "$f" || continue
    mkdir -p "$TARGET_FS_ROOT$( dirname "$f" )"
    # Do not error out at this late state of "rear recover" but inform the user:
    cp -a $v "$f" "$TARGET_FS_ROOT$f"
    cp_rc=$?
    test $cp_rc -eq 0 || { LogPrintError "Failed to copy $f to $TARGET_FS_ROOT$f (cp exit code $cp_rc)." ; copy_failed=true ; }
done

# Check the identity itself landed, that is what the agent needs on next start:
if ! $copy_failed && test -s "$TARGET_FS_ROOT$coh_agent_cfg" ; then
    LogPrint "Cohesity agent identity copied. No further registration is needed after reboot."
else
    LogPrintError "WARNING: The Cohesity agent identity was not copied completely."
    LogPrintError "The Cohesity agent on the recovered system may need to be registered again after reboot."
fi
