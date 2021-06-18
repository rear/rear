# remove the lockfile
local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
local opath=$( backup_path $scheme $path )

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

rm -f $v "${opath}/.lockfile" >&2
