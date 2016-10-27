# remove the lockfile
local scheme=$(url_scheme $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)
local opath=$(output_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

# when OUTPUT_URL=BACKUP_URL we keep the lockfile to avoid double moves of the directory
[[ "$OUTPUT_URL" != "$BACKUP_URL" ]] && rm -f $v "${opath}/.lockfile" >&2
