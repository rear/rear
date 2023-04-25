# 400_prep_nfs_server.sh
#
# prepare stuff for NFS_SERVER
#

PROGS+=("${PROGS_NFS_SERVER[@]}")

REQUIRED_PROGS+=("${REQUIRED_PROGS_NFS_SERVER[@]}")

MODULES_LOAD+=("${NFS_SERVER_MODULES[@]}")

if is_false $NFS_SERVER_V4_ONLY; then
    REQUIRED_PROGS+=("${REQUIRED_PROGS_NFS_SERVER_V3[@]}")
fi