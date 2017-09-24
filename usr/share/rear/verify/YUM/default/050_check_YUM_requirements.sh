# Copied from ../../../prep/NETFS/default/050_check_NETFS_requirements.sh for YUM
# BACKUP_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: usb:///dev/sdb1
# example: tape:///dev/nst0
# example: file:///path
# example: iso://backup/
# example: sshfs://user@host/G/rear/
# example: ftpfs://user:password@host/rear/ (the password part is optional)

[[ "$BACKUP_URL" || "$BACKUP_MOUNTCMD" ]]
# FIXME: The above test does not match the error message below.
# To match the the error message the test should be
# [[ "$BACKUP_URL" || ( "$BACKUP_MOUNTCMD" && "$BACKUP_UMOUNTCMD" ) ]]
# but I <jsmeix@suse.de> cannot decide if there is a subtle reason for the omission.
StopIfError "You must specify either BACKUP_URL or BACKUP_MOUNTCMD and BACKUP_UMOUNTCMD !"

if [[ "$BACKUP_URL" ]] ; then
    local scheme=$( url_scheme $BACKUP_URL )
    local hostname=$( url_hostname $BACKUP_URL )
    local path=$( url_path $BACKUP_URL )

    ### check for vaild BACKUP_URL schemes
    ### see https://github.com/rear/rear/issues/842
    case $scheme in
        (nfs|cifs|usb|tape|file|iso|sshfs|ftpfs)
            # do nothing for vaild BACKUP_URL schemes
            :
            ;;
        (*)
            Error "Invalid scheme '$scheme' in BACKUP_URL '$BACKUP_URL' valid schemes: nfs cifs usb tape file iso sshfs ftpfs"
            ;;
    esac

    ### set other variables from BACKUP_URL
    if [[ "usb" = "$scheme" ]] ; then
        # if USB_DEVICE is not explicitly specified it is the path from BACKUP_URL
        [[ -z "$USB_DEVICE" ]] && USB_DEVICE="$path"
    fi

    ### check if host is reachable
    if [[ "$PING" && "$hostname" ]] ; then
        # Only LogPrintIfError but no StopIfError because it is not a fatal error
        # (i.e. not a reason to abort) when a host does not respond to a 'ping'
        # because hosts can be accessible via certain ports but do not respond to a 'ping'
        # cf. https://bugzilla.opensuse.org/show_bug.cgi?id=616706
        # TODO: it would be better to test if it is accessible via the actually needed port(s)
        ping -c 2 "$hostname" >/dev/null
        LogPrintIfError "Host '$hostname' in BACKUP_URL '$BACKUP_URL' does not respond to a 'ping'."
    else
        Log "Skipping 'ping' test for host '$hostname' in BACKUP_URL '$BACKUP_URL'"
    fi

fi

# some backup progs require a different backuparchive name
case "$(basename $BACKUP_PROG)" in
    (rsync)
        # rsync creates a target directory instead of a file
        BACKUP_PROG_SUFFIX=
        BACKUP_PROG_COMPRESS_SUFFIX=
        ;;
    (*)
        :
        ;;
esac

# include required programs
# the code below includes mount.* and umount.* programs for all non-empty schemes
# (i.e. for any non-empty BACKUP_URL like usb tape file sshfs ftpfs)
# and it includes 'mount.' for empty schemes (e.g. if BACKUP_URL is not set)
# which is o.k. because it is a catch all rule so we do not miss any
# important executable needed a certain scheme and it does not hurt
# see https://github.com/rear/rear/pull/859
PROGS=( "${PROGS[@]}"
showmount
mount.$(url_scheme $BACKUP_URL)
umount.$(url_scheme $BACKUP_URL)
$( test "$BACKUP_MOUNTCMD" && echo "${BACKUP_MOUNTCMD%% *}" )
$( test "$BACKUP_UMOUNTCMD" && echo "${BACKUP_UMOUNTCMD%% *}" )
$BACKUP_PROG
gzip
bzip2
xz
)

# include required stuff for sshfs or ftpfs (via CurlFtpFS)
if [[ "sshfs" = "$scheme" || "ftpfs" = "$scheme" ]] ; then
    # both sshfs and ftpfs (via CurlFtpFS) are based on FUSE
    PROGS=( "${PROGS[@]}" fusermount mount.fuse )
    MODULES=( "${MODULES[@]}" fuse )
    MODULES_LOAD=( "${MODULES_LOAD[@]}" fuse )
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/fuse.conf )
    # include what is specific for sshfs
    if [[ "sshfs" = "$scheme" ]] ; then
        # see http://sourceforge.net/apps/mediawiki/fuse/index.php?title=SshfsFaq
        REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" sshfs )
        # as we're using SSH behind the scenes we need our keys/config file saved
        COPY_AS_IS=( "${COPY_AS_IS[@]}" $HOME/.ssh )
    fi
    # include what is specific for ftpfs
    if [[ "ftpfs" = "$scheme" ]] ; then
        # see http://curlftpfs.sourceforge.net/
        # and https://github.com/rear/rear/issues/845
        REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" curlftpfs )
    fi
fi

# include required modules, like nfs cifs ...
# the code below includes modules for all non-empty schemes
# (i.e. for any non-empty BACKUP_URL like usb tape file sshfs ftpfs)
# which is o.k. because this must been seen as a catch all rule
# (one never knows what one could miss)
# see https://github.com/rear/rear/pull/859
MODULES=( "${MODULES[@]}" $(url_scheme $BACKUP_URL) )

