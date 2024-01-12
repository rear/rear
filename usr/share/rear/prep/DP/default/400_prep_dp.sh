# 400_prep_dp.sh
# Prepare stuff for Data Protector

COPY_AS_IS+=( "${COPY_AS_IS_DP[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_DP[@]}" )
PROGS+=( join head col )

# Use a DP-specific LD_LIBRARY_PATH to find DP libraries
# see https://github.com/rear/rear/pull/2549
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$DP_LD_LIBRARY_PATH"
