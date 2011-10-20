# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to uname -n

# do not do this for tapes and special attention for file:///path
local scheme=$(url_scheme $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)
local opath=$(output_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

mkdir -p $v -m0750 "${opath}" >&2
StopIfError "Could not mkdir '${opath}'"
