#
# prepare stuff for FDRUPSTREAM
#

COPY_AS_IS+=( "${COPY_AS_IS_FDRUPSTREAM[@]}" "${FDRUPSTREAM_INSTALL_PATH}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_FDRUPSTREAM[@]}" )
PROGS+=( "${PROGS_FDRUPSTREAM[@]}" )
REQUIRED_PROGS+=( "${REQUIRED_PROGS_FDRUPSTREAM[@]}" col )

# Use a FDRUPSTREAM-specific LD_LIBRARY_PATH to find FDR libraries
# see https://github.com/rear/rear/pull/2296
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$FDRUPSTREAM_LD_LIBRARY_PATH"
