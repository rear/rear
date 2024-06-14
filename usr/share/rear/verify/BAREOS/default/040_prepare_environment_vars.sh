# read config vars defined during prep.
source "$VAR_DIR/bareos.conf"

if [ -z "$BAREOS_CLIENT" ]; then
    export BAREOS_CLIENT="$HOSTNAME-fd"
fi

if [ -n "$BAREOS_FILESET" ]; then
    export FILESET="fileset=\"$BAREOS_FILESET\""
fi

if [ -n "$BAREOS_RESTORE_JOB" ]; then
    export RESTOREJOB="restorejob=\"$BAREOS_RESTORE_JOB\""
    export RESTOREJOB_AS_JOB="job=\"$BAREOS_RESTORE_JOB\""
fi

if [ -n "$BAREOS_RESTORE_CLIENT" ]; then
    export RESTORECLIENT="restoreclient=\"$BAREOS_RESTORE_CLIENT\""
fi
