#
# prepare variables to be easier used inside bconsole commands.
#

if [ -n "$BAREOS_FILESET" ]; then
    # shellcheck disable=SC2034
    FILESET="fileset=\"$BAREOS_FILESET\""
fi

if [ -n "$BAREOS_RESTORE_JOB" ]; then
    # shellcheck disable=SC2034
    RESTOREJOB="restorejob=\"$BAREOS_RESTORE_JOB\""
    # shellcheck disable=SC2034
    RESTOREJOB_AS_JOB="job=\"$BAREOS_RESTORE_JOB\""
fi
