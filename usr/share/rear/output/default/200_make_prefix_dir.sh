
# Create $OUTPUT_PREFIX directory.
# The $OUTPUT_PREFIX directory defaults to $HOSTNAME.
#
# This happens usually under a mounted network filesystem share
# e.g. in case of OUTPUT_URL=nfs://NFS.server.IP.address/remote/nfs/share
# but it is also happens for local stuff like OUTPUT_URL=usb:///dev/disk/by-label/REAR-000
#
# Do not do this for tapes and special attention for file:///path
local scheme=$( url_scheme $OUTPUT_URL )
local path=$( url_path $OUTPUT_URL )
local opath=$( output_path $scheme $path )

# If $opath is empty return silently (e.g. scheme tape):
test "$opath" || return 0

# Create $OUTPUT_PREFIX sub-directory:
mkdir -p $v -m0750 "$opath" && return

# A failure to create the $OUTPUT_PREFIX sub-directory is fatal:
Error "Failed to create '$opath' directory for OUTPUT_URL=$OUTPUT_URL"

