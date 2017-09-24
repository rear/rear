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

# Have all array members as a single word like "${arr[*]}" because it should detect
# when there is any non-empty array member (not necessarily the first one) and here
# the first array member is always the empty string because of missing_progs=( '' ) above:
contains_visible_char "${missing_progs[*]}" && Error "Cannot find required programs: ${missing_progs[@]}"

