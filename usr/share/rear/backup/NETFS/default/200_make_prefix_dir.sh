# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to $HOSTNAME

# do not do this for tapes and special attention for file:///path
local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

mkdir -p $v -m0750 "${opath}" && return

# A failure to create the $NETFS_PREFIX sub-directory is fatal:
Error "Failed to create '$opath' directory for BACKUP_URL=$BACKUP_URL"
