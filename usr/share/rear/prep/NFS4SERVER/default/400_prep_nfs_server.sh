# 400_prep_nfs_server.sh
#
# prepare stuff for NFS4SERVER
#

PROGS+=("${PROGS_NFS4SERVER[@]}")

REQUIRED_PROGS+=("${REQUIRED_PROGS_NFS4SERVER[@]}")

MODULES_LOAD+=("${NFS4SERVER_MODULES[@]}")

# Check if at least one trusted client was specified
(( "${#NFS4SERVER_TRUSTED_CLIENTS[@]}" > 0 )) || Error "You must have defined at least one client in NFS4SERVER_TRUSTED_CLIENTS."
