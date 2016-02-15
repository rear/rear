# the main script all has the same piece of code (below), but
# other prep scripts can also add binaries to the REQUIRED_PROGS array
# so we need to double check before leaving the prep stage.

# check for requirements, do we have all required binaries ?
# without the empty string as initial value MISSING_PROGS would be
# an unbound variable that would result an error exit if 'set -eu' is used:
declare -a MISSING_PROGS
for f in "${REQUIRED_PROGS[@]}" ; do
    if ! has_binary "$f" ; then
        MISSING_PROGS=( "${MISSING_PROGS[@]}" "$f" )
    fi
done
if test -n "$MISSING_PROGS" ; then
    Error "Cannot find required programs: ${MISSING_PROGS[@]}"
fi

