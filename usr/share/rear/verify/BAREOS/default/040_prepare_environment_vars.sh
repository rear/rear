# read config vars defined during prep.
source "$VAR_DIR/bareos.conf"

if [ -z "$BAREOS_CLIENT" ]; then
    BAREOS_CLIENT="$HOSTNAME-fd"
    export BAREOS_CLIENT
fi

if [ -n "$BAREOS_FILESET" ]; then
    FILESET="fileset=\"$BAREOS_FILESET\""
    export FILESET
fi

if [ -n "$BAREOS_RESTORE_JOB" ]; then
    RESTOREJOB="restorejob=\"$BAREOS_RESTORE_JOB\""
    export RESTOREJOB
    RESTOREJOB_AS_JOB="job=\"$BAREOS_RESTORE_JOB\""
    export RESTOREJOB_AS_JOB
fi

if [ -n "$BAREOS_RESTORE_CLIENT" ]; then
    RESTORECLIENT="restoreclient=\"$BAREOS_RESTORE_CLIENT\""
    export RESTORECLIENT
fi
