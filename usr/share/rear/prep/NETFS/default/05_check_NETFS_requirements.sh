# BACKUP_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: usb:///dev/sdb1
# example: tape:///dev/nst0
# example: file:///path
# example: sshfs://user@host/G/rear/

[[ "$BACKUP_URL" || "$BACKUP_MOUNTCMD" ]]
StopIfError "You must specify either BACKUP_URL or BACKUP_MOUNTCMD and BACKUP_UMOUNTCMD !"

if [[ "$BACKUP_URL" ]] ; then
    local host=$(url_host $BACKUP_URL)
    local scheme=$(url_scheme $BACKUP_URL)
    local path=$(url_path $BACKUP_URL)

    ### set other variables from BACKUP_URL
    case $scheme in
        (usb)
            if [[ -z "$USB_DEVICE" ]] ; then
                USB_DEVICE="$path"
            fi
            ;;
	(sshfs)
	    # check if $host contains a '@' because then we use user@host format
	    echo $host | grep -q '@' && {
		sshfs_user="${host%%@*}"	# save the user
		host="${host#*@}"		# remove user@
		}
	    ;;
    esac

    ### check if host is reachable
    if [[ "$PING" && "$host" ]]; then
        ping -c 2 "$host" >&8
        StopIfError "Backup host [$host] not reachable."
    else
        Log "Skipping ping test"
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

# include required programs
PROGS=( "${PROGS[@]}"
showmount
mount.$(url_scheme $BACKUP_URL)
umount.$(url_scheme $BACKUP_URL)
$(
test "$BACKUP_MOUNTCMD" && echo "${BACKUP_MOUNTCMD%% *}"
test "$BACKUP_UMOUNTCMD" && echo "${BACKUP_UMOUNTCMD%% *}"
)
$BACKUP_PROG
gzip
bzip2
xz
)

[[ "$scheme" = "sshfs" ]] && {	# see http://sourceforge.net/apps/mediawiki/fuse/index.php?title=SshfsFaq
	REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" sshfs )
	PROGS=( "${PROGS[@]}" fusermount mount.fuse )
	MODULES=( "${MODULES[@]}" fuse )
	MODULES_LOAD=( "${MODULES_LOAD[@]}" fuse )
	# as we're using SSH behind the scenes we need our keys/config file saved
	COPY_AS_IS=( "${COPY_AS_IS[@]}" $HOME/.ssh /etc/fuse.conf )
	}
	

# include required modules, like nfs cifs ...
MODULES=( "${MODULES[@]}" $(url_scheme $BACKUP_URL) )
