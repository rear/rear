# 450_check_nbu_client_configured.sh

# Check this client is properly registered on the NetBackup Primary
# server and has a valid backup in the catalog. Flag it early if this
# client is actually a Primary or Media server itself, since restoring
# one needs additional planning, not a straight rear recovery. Check
# True Image Restore info is present in the catalog when
# NBU_TRUE_IMAGE_RESTORE is enabled.

# Check whether this client is actually a NetBackup Primary or Media server
# (CLIENT_NAME matches a SERVER or MEDIA_SERVER entry in its own bp.conf).
# Restoring such a server via rear can't work in a real DR since NetBackup
# services must already be running to run 'bprestore'. Flag this at backup
# time so the operator finds out long before a disaster, not during one.
local nbu_bpconf=/usr/openv/netbackup/bp.conf
test -r "$nbu_bpconf" || Error "Cannot read $nbu_bpconf."
local bp_conf_client_name nbu_server_media_list nbu_server_client_msg
bp_conf_client_name=$( grep -i '^[[:space:]]*CLIENT_NAME[[:space:]]*=' "$nbu_bpconf" | head -1 | sed -e 's/^[^=]*=[[:space:]]*//' -e 's/[[:space:]]*$//' )
nbu_server_media_list=$( grep -iE '^[[:space:]]*(SERVER|MEDIA_SERVER)[[:space:]]*=' "$nbu_bpconf" | sed -e 's/^[^=]*=[[:space:]]*//' -e 's/[[:space:]]*$//' )
if test -n "$bp_conf_client_name" && echo "${nbu_server_media_list,,}" | grep -qFx "${bp_conf_client_name,,}" ; then
    nbu_server_client_msg="This client is a NetBackup Primary/Media server. A SERVER or
MEDIA_SERVER entry in bp.conf matches CLIENT_NAME ($bp_conf_client_name).

Restoring may not work since NetBackup services must be up and running to
run 'bprestore'. During restore time, when running 'rear recover' you will
need to point to another Primary server holding a replicated (or duplicated)
copy of this client's image. If you understand these implications set
NBU_ALLOW_SERVER_AS_CLIENT=true in local.conf/site.conf to continue."
    if is_true "$NBU_ALLOW_SERVER_AS_CLIENT" ; then
        LogPrintError "WARNING: $nbu_server_client_msg"
    else
        Error "$nbu_server_client_msg"
    fi
fi

local nbu_bplist=/usr/openv/netbackup/bin/bplist
test -x "$nbu_bplist" || Error "Cannot execute $nbu_bplist."

local rc nbu_bplist_since nbu_bplist_tir_flag=""
nbu_bplist_since=$( date -d "-1 month" "+%m/%d/%Y" )

# "bplist -T" lists only backups with TIR info and exits 227 if the
# window has none. One call covers both the TIR and backup-exists checks.
is_false "$NBU_TRUE_IMAGE_RESTORE" || nbu_bplist_tir_flag="-T"

if test -z "$nbu_bplist_tir_flag" ; then
    LogPrintError "WARNING: True Image Restore is disabled (NBU_TRUE_IMAGE_RESTORE=false).
Without TIR, a Point-In-Time restore of a full backup plus subsequent
incremental backups may incorrectly restore files or folders deleted
before the picked incremental. Enable 'Collect true image restore
information' (with move detection) in the Attributes tab of the policy
that backs up this client, then remove NBU_TRUE_IMAGE_RESTORE from
local.conf/site.conf. TIR is enabled by default and gives the best DR
experience."
fi

Log "Running: $nbu_bplist $nbu_bplist_tir_flag -s $nbu_bplist_since /"
"$nbu_bplist" $nbu_bplist_tir_flag -s "$nbu_bplist_since" / >/dev/null 2>&1
rc=$?
if [ $rc -eq 227 ] ; then
    # 227: no backups in the window (with -T: none carry TIR info).
    if [ -n "$nbu_bplist_tir_flag" ] ; then
        Error "No backups with TIR information in the NetBackup catalog for this client."
    else
        Error "No backups in the NetBackup catalog for this client."
    fi
elif [ $rc -gt 0 ] ; then
    Error "Netbackup 'bplist' check failed with error code ${rc}.
This client must be able to communicate with the NetBackup Primary server
and have at least one valid backup in the catalog within the last month.
See $RUNTIME_LOGFILE for more details."
else
    Log "Found backups in the NetBackup catalog for this client."
fi
