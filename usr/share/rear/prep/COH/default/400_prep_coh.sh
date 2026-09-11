# 400_prep_coh.sh
# Prepare stuff for Cohesity DataProtect

COPY_AS_IS+=( "${COPY_AS_IS_COH[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_COH[@]}" )
PROGS+=( "${PROGS_COH[@]}" )

# The Cohesity agent ships its own bundled shared libraries (protobuf, absl, rocksdb, ...)
# next to its binaries instead of relying on system libraries, so 'ldd' can only resolve
# them if they are on LD_LIBRARY_PATH:
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$COH_LD_LIBRARY_PATH"
