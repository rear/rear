# verify/default/040_validate_variables.sh

# Test if variable WAIT_SECS is a positive integer,
# if not, give it the default value from default.conf.

# is_positive_integer outputs '0' and returns 1
# if its (first) argument is not a positive integer (or empty):
is_positive_integer $WAIT_SECS 1>/dev/null || WAIT_SECS=30

