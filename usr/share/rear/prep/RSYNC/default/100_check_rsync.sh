# 100_check_rsync.sh - analyze the BACKUP_URL
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if test -z "$BACKUP_URL" ; then
    Error "Missing BACKUP_URL=rsync://[USER@]HOST[:PORT][::]/PATH !"
fi

local scheme="$(url_scheme "$BACKUP_URL")"  # url_scheme still recognizes old style

if [[ "$scheme" != "rsync" ]]; then
    Error "Missing BACKUP_URL=rsync://[USER@]HOST[:PORT][::]/PATH !"
fi

local host proto
host="$(rsync_host "$BACKUP_URL")"
proto="$(rsync_proto "$BACKUP_URL")"

# check if host is reachable
if test "$PING" ; then
    ping -c 2 "$host" >/dev/null || Error "Backup host [$host] not reachable."
else
    Log "Skipping ping test"
fi

# check protocol connectivity
case "$proto" in

    (rsync)
        Log "Test: $BACKUP_PROG ${BACKUP_RSYNC_OPTIONS[*]} $(rsync_remote_base "$BACKUP_URL")"
        $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" $(rsync_remote_base "$BACKUP_URL") >/dev/null \
            || Error "Rsync daemon not running on $host"
        ;;

    (ssh)
        Log "Test: ssh $(rsync_remote_ssh "$BACKUP_URL") /bin/true"
        ssh $(rsync_remote_ssh "$BACKUP_URL") /bin/true >/dev/null 2>&1 \
            || Error "Secure shell connection not setup properly [$(rsync_remote_ssh "$BACKUP_URL")]"
        ;;

esac
