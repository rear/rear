### prepare stuff for BAREOS

CLONE_GROUPS+=( bareos )
COPY_AS_IS+=( "${COPY_AS_IS_BAREOS[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_BAREOS[@]}" )
PROGS+=( "${PROGS_BAREOS[@]}" )
REQUIRED_PROGS+=( "${REQUIRED_PROGS_BAREOS[@]}" )

### empty config file filled by "prep" (and used by restore)
true > "$VAR_DIR/bareos.conf"

if [ -z "$BAREOS_RESTORE_MODE" ]; then
    if [ "$BEXTRACT_DEVICE" ] || [ "$BEXTRACT_VOLUME" ]; then
        BAREOS_RESTORE_MODE="bextract"
    else
        BAREOS_RESTORE_MODE="bconsole"
    fi
    echo "BAREOS_RESTORE_MODE=$BAREOS_RESTORE_MODE" >> "$VAR_DIR/bareos.conf"
fi

LogPrint "BAREOS_RESTORE_MODE=$BAREOS_RESTORE_MODE"

if [ "$BAREOS_RESTORE_MODE" = "bextract" ]; then
    PROGS+=( "${PROGS_BAREOS_BEXTRACT[@]}" )
    REQUIRED_PROGS+=( "${REQUIRED_PROGS_BAREOS_BEXTRACT[@]}" )
else
    PROGS+=( "${PROGS_BAREOS_BCONSOLE[@]}" )
    REQUIRED_PROGS+=( "${REQUIRED_PROGS_BAREOS_BCONSOLE[@]}" )
fi
