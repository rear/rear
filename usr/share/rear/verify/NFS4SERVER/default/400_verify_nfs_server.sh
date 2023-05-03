# 400_verify_nfs_server.sh

# Check if at least one trusted client was specified
(( "${#NFS4SERVER_TRUSTED_CLIENTS[@]}" > 0 )) || Error "You must have defined at least one client in NFS4SERVER_TRUSTED_CLIENTS."
