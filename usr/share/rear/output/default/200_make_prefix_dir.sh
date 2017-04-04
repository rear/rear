# if set, create $OUTPUT_PREFIX under the mounted network filesystem share. This defaults
# to $HOSTNAME

# do not do this for tapes and special attention for file:///path
url="$( echo $stage | tr '[:lower:]' '[:upper:]')_URL"
local scheme=$(url_scheme ${!url})
local path=$(url_path ${!url})
local opath=$(output_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

if [[ "$OUTPUT" == "PXE" && "$scheme" == "nfs" ]]; then
    mkdir -p $v -m0755 "${opath}" >&2
else
    mkdir -p $v -m0750 "${opath}" >&2
fi
StopIfError "Could not mkdir '${opath}'"
