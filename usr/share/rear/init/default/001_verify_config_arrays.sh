# Ensure that all array variables are assigned as arrays in user provided configuration.
# This avoids user config mistakes which can lead to obscure and severe errors,
# see https://github.com/rear/rear/issues/2930 and for an example
# see https://github.com/rear/rear/issues/2911
#
# Bash variables retain the array attribute even if name=value syntax is used to assign
# a new value because the new assignment changes the first member of the array.
# Therefore it is enough to take all currently defined array variables
# and check for wrong assignments in the user configuration.

# Skip this test when 'mapfile' (a bash 4.x builtin) is not available:
# sed from such old systems also don't support -E
type -a mapfile 1>/dev/null || return 0

local -a var_assignments array_variables

mapfile -t array_variables < <(
    declare -p | sed -n -E -e '/^declare -a/s/declare [-arxlu]+ ([A-Za-z0-9_-]+)=.*/\1/p'
)

for config in "$CONFIG_DIR"/{site,local,rescue}.conf "${CONFIG_APPEND_FILES_PATHS[@]}"; do
    test -r "$config" || continue
    for var in "${array_variables[@]}"; do
        # Do not check comment lines for falsely assigned array variables:
        mapfile -t var_assignments < <(
            grep -v '^[[:space:]]*#' "$config" | sed -n -E -e "/(^|\W+)$var\+?=/p"
            )
        for line in "${var_assignments[@]}"; do
            [[ "$line" == *$var?(+)=\(* ]] || Error "Syntax error: Variable $var not assigned as Bash array in $config:$LF$line$LF"
        done
    done
done
