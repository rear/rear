#
# prepare stuff for BACULA
#
CLONE_GROUPS=( "${CLONE_GROUPS[@]}" bacula )
COPY_AS_IS=( "${COPY_AS_IS[@]}" "${COPY_AS_IS_BACULA[@]}" )
COPY_AS_IS_EXCLUDE=( "${COPY_AS_IS_EXCLUDE[@]}" "${COPY_AS_IS_EXCLUDE_BACULA[@]}" )
PROGS=( "${PROGS[@]}" "${PROGS_BACULA[@]}" )
