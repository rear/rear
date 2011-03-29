# NETFS_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: usb:///dev/sdb1
# example: tape:///dev/nst0
# example: obdr:///dev/nst0

NETFS_PROTO=
NETFS_HOST=
NETFS_SHARE=
NETFS_MOUNTPATH=

# check for complete information, we need either NETFS_URL or NETFS_MOUNTCMD/UMOUNTCMD
if test -z "$NETFS_URL" ; then
	if ! test "$NETFS_MOUNTCMD" -a "$NETFS_UMOUNTCMD" ; then
		ProgressStopIfError 1 "You must specify either NETFS_URL or NETFS_MOUNTCMD and NETFS_UMOUNTCMD !"
	fi
else
	# we have an URL, break it into parts
	NETFS_PROTO="${NETFS_URL%%://*}"
	tmp="${NETFS_URL##*://}"
	NETFS_HOST="${tmp%%/*}"
	NETFS_SHARE="${tmp#*/}"

	# NETFS_MOUNTPATH is the string that the mount command expects to get to access the
	# remote share. Default is host:/share format
	NETFS_MOUNTPATH="$NETFS_HOST:/$NETFS_SHARE"

	# special treatments for some protocols
	case "$NETFS_PROTO" in
		cifs)
			NETFS_MOUNTPATH="//$NETFS_HOST/$NETFS_SHARE" ;;
		usb )
			NETFS_MOUNTPATH="/$NETFS_SHARE"
			NETFS_HOST=localhost	# otherwise, ping could fail
			USB_DEVICE="/$NETFS_SHARE"
			;;
		*) ;;
	esac

	# check if host is reachable
	if test "$PING" ; then
		ping -c 2 "$NETFS_HOST" 1>&8
		ProgressStopIfError $? "Backup host [$NETFS_HOST] not reachable."
	else
		Log "Skipping ping test"
	fi

fi

# some backup progs require a different backuparchive name
case "$BACKUP_PROG" in
	(rsync)
		# rsync creates a target directory instead of a file
		BACKUP_PROG_SUFFIX=
		BACKUP_PROG_COMPRESS_SUFFIX=
		;;
	(*)	:
		;;
esac

# set archive names
case "$TAPE_DEVICE:$NETFS_PROTO" in
	(:*)
		backuparchive="${BUILD_DIR}/netfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}" ;;
	(*:obdr)
		backuparchive="${TAPE_DEVICE}" ;;
	(*:tape)
		backuparchive="${TAPE_DEVICE}" ;;
esac

if test "$NETFS_MOUNTCMD" -a "$NETFS_UMOUNTCMD" ; then
	displayarchive="$backuparchive"
else
	displayarchive="$NETFS_URL/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
fi


# include required programs
# please note that this is just for safety reasons. Most of these programs are also listet in conf/GNU/Linux.conf !

PROGS=( "${PROGS[@]}"
ping
showmount
portmap
rpcbind
rpcinfo
mount
mount.$NETFS_PROTO
umount.$NETFS_PROTO
$( 
test "$NETFS_MOUNTCMD" && echo "${NETFS_MOUNTCMD%% *}"
test "$NETFS_UMOUNTCMD" && echo "${NETFS_UMOUNTCMD%% *}"
)
$BACKUP_PROG
gzip
bzip2
)

# include required modules, like nfs cifs ...
MODULES=( "${MODULES[@]}" $NETFS_PROTO )
