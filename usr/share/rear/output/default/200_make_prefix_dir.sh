
# Create $OUTPUT_PREFIX directory.
# The $OUTPUT_PREFIX directory defaults to $HOSTNAME.
#
# This happens usually under a mounted network filesystem share
# e.g. in case of OUTPUT_URL=nfs://NFS.server.IP.address/remote/nfs/share
# but it is also happens for local stuff like OUTPUT_URL=usb:///dev/disk/by-label/REAR-000

# Do not do this for tapes and special attention for file:///path
local scheme=$( url_scheme $OUTPUT_URL )
local path=$( url_path $OUTPUT_URL )

# If filesystem access to url is unsupported return silently (e.g. scheme tape)
scheme_supports_filesystem $scheme || return 0

local opath=$( output_path $scheme $path )

# Create $OUTPUT_PREFIX sub-directory.
# That directory should be neither world-readable nor world-writable
# because it contains confidential data. In particular it may contain
# the backup of (almost) all files of the system:
mkdir -p $v -m0750 "$opath" && return

# A failure to create the $OUTPUT_PREFIX sub-directory is fatal:
Error "Failed to create '$opath' directory for OUTPUT_URL=$OUTPUT_URL"

