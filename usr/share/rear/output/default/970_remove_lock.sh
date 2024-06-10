# remove the lockfile
local scheme="$( url_scheme "$OUTPUT_URL" )"
local path="$( url_path "$OUTPUT_URL" )"

# if filesystem access to url is unsupported return silently (e.g. scheme tape)
scheme_supports_filesystem "$scheme" || return 0

local opath="$( output_path "$scheme" "$path" )"

# when OUTPUT_URL=BACKUP_URL we keep the lockfile to avoid double moves of the directory
[[ "$OUTPUT_URL" != "$BACKUP_URL" ]] && rm -f $v "${opath}/.lockfile" >&2
