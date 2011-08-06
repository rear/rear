# NETFS_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: usb:///dev/sdb1
# example: tape:///dev/nst0

[[ "$NETFS_URL" || "$NETFS_MOUNTCMD" ]]
StopIfError "You must specify either NETFS_URL or NETFS_MOUNTCMD and NETFS_UMOUNTCMD !"

if [[ "$NETFS_URL" ]] ; then
    local host=$(url_host $NETFS_URL)

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

    ### set other variables from NETFS_URL
    case $(url_scheme $NETFS_URL) in
        (usb)
            if [[ -z "$USB_DEVICE" ]] ; then
                USB_DEVICE="/$(url_path $NETFS_URL)"
            fi
            ;;
    esac

    if [[ -z "$ISO_URL" ]] ; then
        if [[ -z "$ISO_MOUNTCMD" ]] ; then
            ISO_URL=$NETFS_URL
        fi
    fi
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
case "$TAPE_DEVICE:$(url_scheme $NETFS_URL)" in
	(:*)
		backuparchive="${BUILD_DIR}/outputfs/${NETFS_PREFIX}/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
		;;
	(*:tape)
		backuparchive="${TAPE_DEVICE}"
		;;
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
mount.$(url_scheme $NETFS_URL)
umount.$(url_scheme $NETFS_URL)
$(
test "$NETFS_MOUNTCMD" && echo "${NETFS_MOUNTCMD%% *}"
test "$NETFS_UMOUNTCMD" && echo "${NETFS_UMOUNTCMD%% *}"
)
$BACKUP_PROG
gzip
bzip2
)

# include required modules, like nfs cifs ...
MODULES=( "${MODULES[@]}" $(url_scheme $NETFS_URL) )
