# 250_check_nbu_client_name.sh

# Detect whether the rescue system hostname differs from the original
# client CLIENT_NAME in bp.conf. Pause so the operator can confirm the
# rename, or edit bp.conf by hand to point this restore at a different
# Primary or Media server, before any NetBackup service starts or any
# certificate gets enrolled.

local nbu_bpconf=/usr/openv/netbackup/bp.conf
test -r "$nbu_bpconf" || Error "Cannot read $nbu_bpconf."

local bp_conf_client_name current_hostname rc
bp_conf_client_name=$( grep -i '^[[:space:]]*CLIENT_NAME[[:space:]]*=' "$nbu_bpconf" | head -1 | sed -e 's/^[^=]*=[[:space:]]*//' -e 's/[[:space:]]*$//' )
# Not "bpclntcmd -gethostname": it just echoes back bp.conf's own CLIENT_NAME
# rather than doing a live hostname lookup, so it would always equal
# $bp_conf_client_name below and the rename detection could never fire.
current_hostname=$( hostname -f 2>&1 )
rc=$?
Log "hostname -f raw output (rc=$rc):"
Log "$current_hostname"
test $rc -eq 0 -a -n "$current_hostname" || Error "Failed to determine current hostname (hostname -f failed, rc=$rc)."

# Exported for 350_start_netbackup.sh to reuse, instead of running
# hostname -f a second time in the same rear run:
export NBU_CLIENT_CURRENT_HOSTNAME="$current_hostname"

# Remember the ORIGINAL client name before any potential patching below (display/hint only):
NBU_CLIENT_ORIGINAL="$bp_conf_client_name"

LogPrint ""
LogPrint "Original client name in bp.conf: ${bp_conf_client_name:-<unknown>}."
LogPrint "Current hostname: $current_hostname."

if test -n "$bp_conf_client_name" \
    && test "${bp_conf_client_name,,}" != "${current_hostname,,}" ; then
    LogPrint "Hostname differs from the original client name in bp.conf."
    LogPrint "CLIENT_NAME will be updated to $current_hostname if you continue below."
    NBU_CLIENT_RENAMED="yes"
else
    LogPrint "Hostname matches the original client name in bp.conf."
    NBU_CLIENT_RENAMED="no"
fi

LogPrint ""
LogPrint "Current NetBackup server entries in $nbu_bpconf:"
LogPrint "$( grep -iE '^[[:space:]]*(SERVER|MEDIA_SERVER)' "$nbu_bpconf" )"

# Check whether this client is actually a NetBackup Primary or Media server
local nbu_server_media_list
nbu_server_media_list=$( grep -iE '^[[:space:]]*(SERVER|MEDIA_SERVER)[[:space:]]*=' "$nbu_bpconf" | sed -e 's/^[^=]*=[[:space:]]*//' -e 's/[[:space:]]*$//' )
if test -n "$bp_conf_client_name" && echo "${nbu_server_media_list,,}" | grep -qFx "${bp_conf_client_name,,}" ; then
    LogPrint ""
    Error "This client is a NetBackup Primary/Media server. A SERVER or
MEDIA_SERVER entry in bp.conf matches CLIENT_NAME ($bp_conf_client_name).

Restoring may not work since NetBackup services must be up and running to
run 'bprestore'. Update SERVER and MEDIA_SERVER and try again. You must point
to another Primary server holding a replicated (or duplicated) copy of this
client's image."
fi

LogPrint ""

# Resolved once here, reused by 500_request_pit_restore_parameters.sh and
# restore/NBU/default/400_restore_with_nbu.sh (same 'rear recover' run):
NBU_TIR_FLAG=""
is_false "$NBU_TRUE_IMAGE_RESTORE" || NBU_TIR_FLAG="-T"
if test -n "$NBU_TIR_FLAG" ; then
    LogPrint "True Image Restore is enabled (NBU_TRUE_IMAGE_RESTORE=true)."
    LogPrint "TIR will provide the best DR experience and is enabled by default."
else
    LogPrint "True Image Restore is disabled (NBU_TRUE_IMAGE_RESTORE=false)."
    LogPrint "Without TIR, a restore assembled from a full backup and subsequent"
    LogPrint "incremental backups may reintroduce deleted or renamed items."
    LogPrint "TIR will provide the best DR experience and is enabled by default."
    LogPrint "To change this, edit NBU_TRUE_IMAGE_RESTORE in local.conf/site.conf"
    LogPrint "before running 'rear recover'."
fi
LogPrint ""
LogPrint "NetBackup services have not been started yet and no certificate has"
LogPrint "been enrolled. If this restore should use a different Primary or"
LogPrint "Media server (e.g. a DR-site NetBackup server), EXIT below and edit"
LogPrint "bp.conf now."
LogPrint ""

read -t $WAIT_SECS -r -p "Press ENTER to continue with the current bp.conf, or enter EXIT to abort [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
if [[ "${REPLY^^}" == "EXIT" ]] ; then
    LogPrint ""
    Error "User aborted NetBackup restore to edit bp.conf or change the hostname."
fi

if is_true "$NBU_CLIENT_RENAMED" ; then
    sed -i "s/^\([[:space:]]*CLIENT_NAME[[:space:]]*=\).*/\1 $current_hostname/" "$nbu_bpconf" || Error "Unable to update CLIENT_NAME in $nbu_bpconf."
    LogPrint ""
    LogPrint "Updated CLIENT_NAME to $current_hostname in bp.conf."
    LogPrint "Restoring under this temporary client name."
fi
