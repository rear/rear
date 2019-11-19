#
# prepare stuff for CDM
#

COPY_AS_IS=( "${COPY_AS_IS[@]}" "${COPY_AS_IS_CDM[@]}" )
COPY_AS_IS_EXCLUDE=( "${COPY_AS_IS_EXCLUDE[@]}" "${COPY_AS_IS_EXCLUDE_CDM[@]}" )
PROGS=( "${PROGS[@]}" "${PROGS_CDM[@]}" fmt )
