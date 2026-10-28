# 400_prep_nbu.sh

# Wire NBU into the rear backup-prep stage. Add the NBU COPY_AS_IS and
# COPY_AS_IS_EXCLUDE file lists. Point the backup tool library search path
# at the NBU libraries instead of the libraries bundled with rear.

COPY_AS_IS+=( "${COPY_AS_IS_NBU[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_NBU[@]}" )

# Use a NBU-specific LD_LIBRARY_PATH to find NBU libraries
# see https://github.com/rear/rear/issues/1974
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$NBU_LD_LIBRARY_PATH"
