# 210_rsync_retention_days.sh
# BACKUP_RSYNC_RETENTION_DAYS= or BACKUP_RSYNC_RETENTION_DAYS=5

[[ -z "$BACKUP_RSYNC_RETENTION_DAYS" ]] && return   # empty means no retention is requested

local proto
proto="$(rsync_proto "$BACKUP_URL")"

if [[ "$proto" == "rsync" ]] ; then
    Error "BACKUP=RSYNC: cannot use retention days with the rsync protocol, use ssh protocol instead."
fi

if (( $BACKUP_RSYNC_RETENTION_DAYS )) ; then
    LogPrint "Using rsync with retention days of $BACKUP_RSYNC_RETENTION_DAYS"
else
    LogPrint "The BACKUP_RSYNC_RETENTION_DAYS value was non-numeric ($BACKUP_RSYNC_RETENTION_DAYS). Using value 10 days."
    BACKUP_RSYNC_RETENTION_DAYS=10
fi

# The RSYNC_* variables will be saved in the /etc/rear/rescue.conf file
RSYNC_TODAY="$(date "+%F")"  # e.g. 2026-01-26
RSYNC_BACKUP="$RSYNC_TODAY"
