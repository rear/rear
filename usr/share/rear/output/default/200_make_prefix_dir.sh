
# Create $OUTPUT_PREFIX directory under the mounted network filesystem share.
# The $OUTPUT_PREFIX directory defaults to $HOSTNAME.
#
# Do not do this for tapes and special attention for file:///path

# Generate url variable name that depends on the current stage, e.g. BACKUP_URL:
url="$( echo $stage | tr '[:lower:]' '[:upper:]' )_URL"

local scheme=$( url_scheme ${!url} )
local path=$( url_path ${!url} )
local opath=$( output_path $scheme $path )

# If $opath is empty return silently (e.g. scheme tape):
test "$opath" || return 0

# Create $OUTPUT_PREFIX sub-directory under the mounted network filesystem share:
mkdir -p $v -m0750 "$opath" && return 0

# A failure to cerate the $OUTPUT_PREFIX sub-directory is fatal: 
Error "Failed to create '$OUTPUT_PREFIX' directory under the mounted network filesystem share"

