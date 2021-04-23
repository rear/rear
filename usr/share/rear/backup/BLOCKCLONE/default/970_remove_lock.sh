# remove the lockfile
url="$( echo $stage | tr '[:lower:]' '[:upper:]')_URL"
local scheme=$(url_scheme ${!url})
local path=$(url_path ${!url})
local opath=$(backup_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

rm -f $v "${opath}/.lockfile" >&2
