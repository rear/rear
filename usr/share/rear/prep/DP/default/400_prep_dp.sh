#
# prepare stuff for DP
#

COPY_AS_IS+=( "${COPY_AS_IS_DP[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_DP[@]}" )
PROGS+=( join head col )
