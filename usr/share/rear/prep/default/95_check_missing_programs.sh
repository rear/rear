# the main script all has the same piece of code (below), but
# other prep scripts can also add binaries to the REQUIRED_PROGS array
# so we need to double check before leaving the prep stage.

# check for requirements, do we have all required binaries ?
MISSING_PROGRS=()
for f in "${REQUIRED_PROGS[@]}" ; do
        if ! has_binary "$f"; then
                MISSING_PROGS=( "${MISSING_PROGS[@]}" "$f" )
        fi
done
[[ -z "$MISSING_PROGS" ]]
StopIfError "Cannot find required programs: ${MISSING_PROGS[@]}"

