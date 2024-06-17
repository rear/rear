if [ -n "$BAREOS_FILESET" ]; then
    export FILESET="fileset=\"$BAREOS_FILESET\""
fi

if [ -n "$BAREOS_RESTORE_JOB" ]; then
    export RESTOREJOB="restorejob=\"$BAREOS_RESTORE_JOB\""
    export RESTOREJOB_AS_JOB="job=\"$BAREOS_RESTORE_JOB\""
fi
