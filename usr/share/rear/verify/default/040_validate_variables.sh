# verify/default/040_validate_variables.sh

# test if variable WAIT_SECS is an integer, if not, give it the default value
if [[ ! -z "$WAIT_SECS" ]]; then
    WAIT_SECS=$( is_numeric $WAIT_SECS )  # if 0 then bsize was not numeric
    [[ $WAIT_SECS -eq 0 ]] && WAIT_SECS=30
else
    WAIT_SECS=30
fi

