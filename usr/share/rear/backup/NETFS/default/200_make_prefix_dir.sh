# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to $HOSTNAME

# do not do this for tapes and special attention for file:///path
url="$( echo $stage | tr '[:lower:]' '[:upper:]' )_URL"
local scheme=$( url_scheme ${!url} )
local path=$( url_path ${!url} )
local opath=$( backup_path $scheme $path )

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

mkdir -p $v -m0750 "${opath}" && return

# A failure to create the $NETFS_PREFIX sub-directory is fatal:
Error "Failed to create '$opath' directory for $url=${!url}"
