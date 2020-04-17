### prepare stuff for BAREOS
CLONE_GROUPS+=( bareos )
COPY_AS_IS+=( "${COPY_AS_IS_BAREOS[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_BAREOS[@]}" )
PROGS+=( "${PROGS_BAREOS[@]}" )

### Include mt when we are restoring from Bareos tape (for troubleshooting)
if [[ "$TAPE_DEVICE" || "$BEXTRACT_DEVICE" ]] ; then
    COPY_AS_IS+=( mt )
fi
