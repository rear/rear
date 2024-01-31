#
# prepare stuff for NBU
#

COPY_AS_IS+=( "${COPY_AS_IS_NBU[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_NBU[@]}" )
PROGS+=( "${PROGS_NBU[@]}" col )

# Use a NBU-specific LD_LIBRARY_PATH to find NBU libraries
# see https://github.com/rear/rear/issues/1974
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$NBU_LD_LIBRARY_PATH"
