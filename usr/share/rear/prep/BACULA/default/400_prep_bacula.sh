### prepare stuff for BACULA
CLONE_GROUPS+=( bacula )
COPY_AS_IS+=( "${COPY_AS_IS_BACULA[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_BACULA[@]}" )
PROGS+=( "${PROGS_BACULA[@]}" )

### Include mt when we are restoring from Bacula tape (for troubleshooting)
if [[ "$TAPE_DEVICE" || "$BEXTRACT_DEVICE" ]] ; then
    PROGS+=( mt )
fi
