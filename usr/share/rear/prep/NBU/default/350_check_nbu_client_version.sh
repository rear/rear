# 350_check_nbu_client_version.sh

# Reject NetBackup client versions too old to have Cohesity support.
# NetBackup 8.1 and later implement host certificates for client-primary
# communication, and this is mandatory for what we do here. Clients
# older than version 8.1 aren't supported.

local nbu_version_file=/usr/openv/netbackup/bin/version
local nbu_min_nbu_version=8.1
local nbu_client_version

if ! test -f "$nbu_version_file" ; then
    Error "Cannot determine the NetBackup client version ($nbu_version_file not found)."
fi

nbu_client_version=$( awk '{print $NF}' "$nbu_version_file" )

# $nbu_version_file's last field is the version (confirmed live, e.g.
# "NetBackup-RedHat4.18.0 11.1.0.2"). Reject anything that doesn't look
# like a dotted version number instead of feeding a surprise format
# straight into version_newer, which would silently mis-compare it:
if [[ ! "$nbu_client_version" =~ ^[0-9]+(\.[0-9]+)*$ ]] ; then
    Error "Cannot determine the NetBackup client version (failed to parse $nbu_version_file)."
fi

if ! version_newer "$nbu_client_version" "$nbu_min_nbu_version" ; then
    Error "NetBackup client $nbu_client_version is not supported by this backend (NetBackup $nbu_min_nbu_version or later is required)."
fi

Log "NetBackup client version $nbu_client_version detected (minimum supported is $nbu_min_nbu_version)."
