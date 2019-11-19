# verify/default/040_validate_variables.sh

# Ensure USER_INPUT_TIMEOUT and WAIT_SECS are positive integers
# to ensure commands like 'read -t $WAIT_SECS' will not fail
# or not wait at all (which happens for 'read -t 0').

# is_positive_integer outputs '0' and returns 1
# if its (first) argument is not a positive integer (or empty).

# Test if USER_INPUT_TIMEOUT is a positive integer,
# if not, set the default value as in default.conf:
is_positive_integer $USER_INPUT_TIMEOUT 1>/dev/null || USER_INPUT_TIMEOUT=300

# Test if WAIT_SECS is a positive integer,
# if not, set the default value as in default.conf:
is_positive_integer $WAIT_SECS 1>/dev/null || WAIT_SECS="$USER_INPUT_TIMEOUT"

