# BACKUP_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: usb:///dev/sdb1
# example: tape:///dev/nst0

[[ "$BACKUP_URL" || "$BACKUP_MOUNTCMD" ]]
StopIfError "You must specify either BACKUP_URL or BACKUP_MOUNTCMD and BACKUP_UMOUNTCMD !"

if [[ "$BACKUP_URL" ]] ; then
    local host=$(url_host $BACKUP_URL)

    if [[ -z "$host" ]] ; then
        host="localhost" # otherwise, ping could fail
    fi

    ### check if host is reachable
    if [[ "$PING" ]]; then
            ping -c 2 "$host" >&8
            StopIfError "Backup host [$host] not reachable."
    else
            Log "Skipping ping test"
    fi

    ### set other variables from BACKUP_URL
    case $(url_scheme $BACKUP_URL) in
        (usb)
            if [[ -z "$USB_DEVICE" ]] ; then
                USB_DEVICE="/$(url_path $BACKUP_URL)"
            fi
            ;;
    esac
fi

# some backup progs require a different backuparchive name
case "$(basename $BACKUP_PROG)" in
	(rsync)
		# rsync creates a target directory instead of a file
		BACKUP_PROG_SUFFIX=
		BACKUP_PROG_COMPRESS_SUFFIX=
		;;
	(*)	:
		;;
esac

# set archive names
case "$TAPE_DEVICE:$(url_scheme $BACKUP_URL)" in
	(:*)
		backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
		;;
	(*:tape)
		backuparchive="${TAPE_DEVICE}"
		;;
esac

if test "$BACKUP_MOUNTCMD" -a "$BACKUP_UMOUNTCMD" ; then
	displayarchive="$backuparchive"
else
	displayarchive="$BACKUP_URL/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
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
mount.$(url_scheme $BACKUP_URL)
umount.$(url_scheme $BACKUP_URL)
$(
test "$BACKUP_MOUNTCMD" && echo "${BACKUP_MOUNTCMD%% *}"
test "$BACKUP_UMOUNTCMD" && echo "${BACKUP_UMOUNTCMD%% *}"
)
$BACKUP_PROG
gzip
bzip2
)

# include required modules, like nfs cifs ...
MODULES=( "${MODULES[@]}" $(url_scheme $BACKUP_URL) )
