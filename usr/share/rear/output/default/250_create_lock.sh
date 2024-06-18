# create a lockfile in $OUTPUT_PREFIX to avoid that mkrescue overwrites ISO/PXE/LOGFILE
# made by a previous mkrescue run when the variable KEEP_OLD_OUTPUT_COPY has been set

# do not do this for tapes and special attention for file:///path
local scheme="$( url_scheme "$OUTPUT_URL" )"
local path="$( url_path "$OUTPUT_URL" )"

# if filesystem access to url is unsupported return silently (e.g. scheme tape)
scheme_supports_filesystem $scheme || return 0

local opath="$( output_path "$scheme" "$path" )"

if test -d "${opath}" ; then
    > "${opath}/.lockfile" || Error "Could not create '${opath}/.lockfile'"
fi
