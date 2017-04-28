# The main script usr/sbin/rear has the same kind of code
# but other prep scripts can add binaries to the REQUIRED_PROGS array
# so we need to double check before leaving the prep stage.

# Without the empty string as initial value missing_progs ${missing_progs[*]} ${missing_progs[@]}
# would all be unbound variables that would result an error exit if 'set -eu' is used:
missing_progs=( '' )

# Check for required binaries:
for prog in "${REQUIRED_PROGS[@]}" ; do
    has_binary "$prog" || missing_progs=( "${missing_progs[@]}" "$prog" )
done

# For the 'test' one must have all array members as a single word like "${arr[*]}" with double-quotes
# because it should detect when there is any non-empty array member (not necessarily the first one)
# but here the first array member is always the empty string because of missing_progs=( '' ) above
# and test must have all as one argument (otherwise on gets 'bash: test: unary operator expected').
# But on the other hand the test should not succeed when there are only empty or blank members
# which would falsely succeed when the array is e.g. something like arr=( '' ' ' ) because then
# "${arr[*]}" evaluates to "  " (the empty and blank members separated by the first character of IFS).
# and test "${arr[*]}" results true for any non-empty argument (e.g. test " " results true).
# Therefore 'echo -n' is interposed because the output of arr=( '' ' ' ) ; echo -n ${arr[*]}
# is empty when the array has only empty or blank array members:
test "$( echo -n ${missing_progs[*]} )" && Error "Cannot find required programs: ${missing_progs[@]}"

