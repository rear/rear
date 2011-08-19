# 10_check_rsync.sh - analyze the BACKUP_URL
## from man page:
# Access via remote shell:
#	Pull: rsync [OPTION...] [USER@]HOST:SRC... [DEST]
#	Push: rsync [OPTION...] SRC... [USER@]HOST:DEST
# Access via rsync daemon:
#	Pull: rsync [OPTION...] [USER@]HOST::SRC... [DEST]
#	rsync [OPTION...] rsync://[USER@]HOST[:PORT]/SRC... [DEST]
#	Push: rsync [OPTION...] SRC... [USER@]HOST::DEST
#	rsync [OPTION...] SRC... rsync://[USER@]HOST[:PORT]/DEST
#
#### rear needs a destination path which is the SRC (or DST)
# BACKUP_URL=[USER@]HOST:PATH			# using ssh (no rsh)
# with rsync protocol PATH is a MODULE name defined in remote /etc/rsyncd.conf file
# BACKUP_URL=[USER@]HOST::PATH			# using rsync
# BACKUP_URL=rsync://[USER@]HOST[:PORT]/PATH	# using rsync

RSYNC_PROTO=					# ssh or rsync
RSYNC_USER=
RSYNC_HOST=
RSYNC_PORT=873					# default port (of rsync server)
RSYNC_PATH=

if test -z "$BACKUP_URL" ; then
	Error "You must specify BACKUP_URL !"
fi

echo $BACKUP_URL | egrep -q '(rsync:|::)'
if [ $? -eq 0 ]; then
	RSYNC_PROTO=rsync
else
	RSYNC_PROTO=ssh
fi

tmp="${BACKUP_URL##*://}"	# remove rsync:// if present
echo $tmp | grep -q '@'
if [ $? -eq 0 ]; then
	RSYNC_USER="${tmp%%@*}"	# grap user name
else
	RSYNC_USER=root
fi

# remove USER@ if present (we don't need it anymore)
tmp2="${tmp#*@}"

case "$RSYNC_PROTO" in

	(rsync)
		echo $tmp2 | grep -q '::'
		if [ $? -eq 0 ]; then
			RSYNC_HOST="${tmp2%%::*}"
			RSYNC_PATH="${tmp2##*::}"
		else
			echo $tmp2 | grep -q ':'
			if [ $? -eq 0 ]; then
				RSYNC_HOST="${tmp2%%:*}"
				tmp="${tmp2##*:}"
				RSYNC_PORT="${tmp%%/*}"
				RSYNC_PATH="${tmp##*/}"
			else
				RSYNC_HOST="${tmp2%%/*}"
				RSYNC_PATH="${tmp2##*/}"
			fi
		fi
		;;
	(ssh)
		RSYNC_HOST="${tmp2%%:*}"
		RSYNC_PATH="${tmp2##*:}"
		;;

esac

#echo RSYNC_PROTO=$RSYNC_PROTO
#echo RSYNC_USER=$RSYNC_USER
#echo RSYNC_HOST=$RSYNC_HOST
#echo RSYNC_PORT=$RSYNC_PORT
#echo RSYNC_PATH=$RSYNC_PATH

# check if host is reachable
if test "$PING" ; then
	ping -c 2 "$RSYNC_HOST" >&8
	StopIfError "Backup host [$RSYNC_HOST] not reachable."
else
	Log "Skipping ping test"
fi

# check protocol connectivity
case "$RSYNC_PROTO" in

	(rsync)
		Log "Test: $BACKUP_PROG ${RSYNC_PROTO}://${RSYNC_HOST}:${RSYNC_PORT}/"
		$BACKUP_PROG ${RSYNC_PROTO}://${RSYNC_HOST}:${RSYNC_PORT}/ >&8
		StopIfError "Rsync daemon not running on $RSYNC_HOST"
		;;

	(ssh)
		Log "Test: ssh ${RSYNC_USER}@${RSYNC_HOST} /bin/true"
		ssh ${RSYNC_USER}@${RSYNC_HOST} /bin/true >&8 2>&1
		StopIfError "Secure shell connection not setup properly [$RSYNC_USER@$RSYNC_HOST]"
		;;

esac
