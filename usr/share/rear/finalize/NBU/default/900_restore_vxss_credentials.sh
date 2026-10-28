# 900_restore_vxss_credentials.sh

# Copy the host certificate/keystore ('vxss'), the Primary CA
# certificate ('webtruststore'), and the credential cache
# ('credcache') from this rescue system onto the recovered disk. All
# three were excluded from the backup and are needed for the
# NetBackup client to stay operational after reboot, without another
# manual token enrollment. Skipped on a cross restore, since the
# enrolled material belongs to the destination client, not the
# restored source. Also skipped when CLIENT_NAME was renamed for this
# rescue boot: the restored /etc/hostname (from the backup) takes over
# again on the next reboot, so a cert enrolled under the temporary
# rescue hostname would no longer match the recovered system's real
# hostname.

if is_true "$NBU_CLIENT_RENAMED" ; then
    LogPrint "CLIENT_NAME was changed for this rescue boot ($NBU_CLIENT_ORIGINAL -> $NBU_CLIENT_NAME)."
    LogPrint "Skipping vxss/webtruststore/credcache copy. The certificate enrolled here belongs to that temporary hostname, not the hostname the recovered system boots back up as."
    LogPrint "The NetBackup client certificate must be reissued after the recovered system has rebooted under its real hostname."
    return
fi

if test -n "$NBU_CLIENT_SOURCE" \
    && test "${NBU_CLIENT_SOURCE,,}" != "${NBU_CLIENT_NAME,,}" ; then
    LogPrint "This was a cross restore ($NBU_CLIENT_SOURCE's backup onto $NBU_CLIENT_NAME)."
    LogPrint "Skipping vxss/webtruststore/credcache copy. The material enrolled belongs to $NBU_CLIENT_NAME, not $NBU_CLIENT_SOURCE."
    LogPrint "The NetBackup client on the recovered system may need to be re-enrolled manually."
    return
fi

# Directory pairs to mirror from this rescue system onto the recovered disk,
# plus the one file inside each whose presence proves the copy is actually
# useful (not just an empty/partial directory):
local nbu_security_dirs=( /usr/openv/var/vxss /usr/openv/var/webtruststore /usr/openv/var/credcache )
local nbu_security_dirs_proof=( credentials cacert.pem 0 )

local i nbu_dir nbu_target_dir proof cp_rc
for (( i = 0; i < ${#nbu_security_dirs[@]}; i++ )) ; do
    nbu_dir="${nbu_security_dirs[$i]}"
    proof="${nbu_security_dirs_proof[$i]}"
    nbu_target_dir="$TARGET_FS_ROOT$nbu_dir"

    if ! test -d "$nbu_dir" ; then
        LogPrint "No $nbu_dir on this rescue system. Nothing to restore."
        continue
    fi

    LogPrint "Restoring NetBackup client credentials from $nbu_dir into $nbu_target_dir ..."

    # Make sure the target directory exists without wiping any content
    # a prior restore stage may already have placed there:
    mkdir -p "$nbu_target_dir"

    # Copy directory contents (trailing '/.', not a glob, so no quoting
    # pitfalls, and no risk of nesting $nbu_dir's basename inside an
    # already-existing $nbu_target_dir) into the existing target
    # directory, merging rather than replacing it, same idiom as
    # finalize/default/110_bind_mount_proc_sys_dev_run.sh uses for /dev.
    # '-a' preserves mode/ownership/timestamps.
    # Do not error out at this late state of "rear recover" but inform the user:
    cp -a $v "$nbu_dir"/. "$nbu_target_dir"/
    cp_rc=$?
    test $cp_rc -eq 0 || LogPrintError "Failed to copy $nbu_dir content to $nbu_target_dir (cp exit code $cp_rc)."

    # Check the credential material itself landed, that is what NetBackup
    # needs on next start:
    if test $cp_rc -eq 0 \
        && test -n "$( ls -A "$nbu_target_dir/$proof" 2>/dev/null )" ; then
        LogPrint "NetBackup client credentials restored from $nbu_dir."
    else
        LogPrintError "NetBackup client credentials from $nbu_dir were not restored."
        LogPrintError "The NetBackup client on the recovered system may need to be re-enrolled manually."
    fi
done
