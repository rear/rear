# ensure that all array variables have been assigned as Bash arrays in user provided configuration
# fixes common user config errors: https://github.com/rear/rear/issues/2930
#
# Note: Bash variables retain the array attribute even if name=value syntax is used to assign
#       a new value, as this assignment simply changes the first member of the array.
#       Therefore it is enough to simply take all the currently defined array variables and check
#       for any wrong assignment in the user configuration

local var_assignments array_variables

mapfile -t array_variables < <(
    declare -p | sed -n -E -e '/^declare -a/s/declare [-arxlu]+ ([A-Za-z0-9_-]+)=.*/\1/p'
)

declare -p array_variables

for config in "$CONFIG_DIR"/{site,local,rescue}.conf "${CONFIG_APPEND_FILES_PATHS[@]}"; do
    test -r "$config" || continue
    for var in "${array_variables[@]}"; do
        mapfile -t var_assignments < <(
            sed -n -E -e "/(^|\W+)$var\+?=/p" "$config"
            )
        for line in "${var_assignments[@]}"; do
            [[ "$line" == *$var?(+)=\(* ]] || Error "Syntax error: Variable $var not assigned as Bash array in $config:$LF$line$LF"
        done
    done
done
