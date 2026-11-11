# 400_prep_coh.sh

# Wire COH into the rear backup-prep stage. Add the COH COPY_AS_IS and
# COPY_AS_IS_EXCLUDE file lists and the required programs. Point the backup
# tool library search path at the libraries bundled with the Cohesity agent.

COPY_AS_IS+=( "${COPY_AS_IS_COH[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_COH[@]}" )
REQUIRED_PROGS+=( "${REQUIRED_PROGS_COH[@]}" )

# The Cohesity agent ships its own bundled shared libraries (protobuf, absl, rocksdb, ...)
# next to its binaries instead of relying on system libraries, so 'ldd' can only resolve
# them if they are on LD_LIBRARY_PATH:
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$COH_LD_LIBRARY_PATH"
