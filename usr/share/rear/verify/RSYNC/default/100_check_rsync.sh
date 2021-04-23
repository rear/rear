# 100_check_rsync.sh - analyze the BACKUP_URL
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

#### OLD STYLE:
# BACKUP_URL=[USER@]HOST:PATH           # using ssh (no rsh)
#
# with rsync protocol PATH is a MODULE name defined in remote /etc/rsyncd.conf file
# BACKUP_URL=[USER@]HOST::PATH          # using rsync
# BACKUP_URL=rsync://[USER@]HOST[:PORT]/PATH    # using rsync (is not compatible with new style!!!)

#### NEW STYLE:
# BACKUP_URL=rsync://[USER@]HOST[:PORT]/PATH    # using ssh
# BACKUP_URL=rsync://[USER@]HOST[:PORT]::/PATH  # using rsync

if test -z "$BACKUP_URL" ; then
    Error "Missing BACKUP_URL=rsync://[USER@]HOST[:PORT][::]/PATH !"
fi

local host=$(url_host $BACKUP_URL)
local scheme=$(url_scheme $BACKUP_URL)  # url_scheme still recognizes old style
local path=$(url_path $BACKUP_URL)

if [[ "$scheme" != "rsync" ]]; then
    Error "Missing BACKUP_URL=rsync://[USER@]HOST[:PORT][::]/PATH !"
fi

RSYNC_PROTO=                    # ssh or rsync
RSYNC_USER=
RSYNC_HOST=
RSYNC_PORT=873                  # default port (of rsync server)
RSYNC_PATH=


echo $BACKUP_URL | egrep -q '(::)'      # new style '::' means rsync protocol
if [[ $? -eq 0 ]]; then
    RSYNC_PROTO=rsync
else
    RSYNC_PROTO=ssh
fi

echo $host | grep -q '@'
if [[ $? -eq 0 ]]; then
    RSYNC_USER="${host%%@*}"    # grab user name
else
    RSYNC_USER=root
fi

# remove USER@ if present (we don't need it anymore)
tmp2="${host#*@}"

case "$RSYNC_PROTO" in

    (rsync)
        # tmp2=witsbebelnx02::backup or tmp2=witsbebelnx02::
        RSYNC_HOST="${tmp2%%::*}"
        # path=/gdhaese1@witsbebelnx02::backup or path=/backup
        echo $path | grep -q '::'
        if [[ $? -eq 0 ]]; then
            RSYNC_PATH="${path##*::}"
        else
            RSYNC_PATH="${path##*/}"
        fi
        ;;
    (ssh)
        # tmp2=host or tmp2=host:
        RSYNC_HOST="${tmp2%%:*}"
        RSYNC_PATH=$path
        ;;

esac

#echo RSYNC_PROTO=$RSYNC_PROTO
#echo RSYNC_USER=$RSYNC_USER
#echo RSYNC_HOST=$RSYNC_HOST
#echo RSYNC_PORT=$RSYNC_PORT
#echo RSYNC_PATH=$RSYNC_PATH

# check if host is reachable
if test "$PING" ; then
    ping -c 2 "$RSYNC_HOST" >/dev/null
    StopIfError "Backup host [$RSYNC_HOST] not reachable."
else
    Log "Skipping ping test"
fi

# check protocol connectivity
case "$RSYNC_PROTO" in

    (rsync)
        Log "Test: $BACKUP_PROG ${BACKUP_RSYNC_OPTIONS[@]} ${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/"
        $BACKUP_PROG ${BACKUP_RSYNC_OPTIONS[@]} ${RSYNC_PROTO}://${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PORT}/ >/dev/null
        StopIfError "Rsync daemon not running on $RSYNC_HOST"
        ;;

    (ssh)
        Log "Test: ssh ${RSYNC_USER}@${RSYNC_HOST} /bin/true"
        ssh ${RSYNC_USER}@${RSYNC_HOST} /bin/true >/dev/null 2>&1
        StopIfError "Secure shell connection not setup properly [$RSYNC_USER@$RSYNC_HOST]"
        ;;

esac
