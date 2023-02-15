# ensure that all array variables defined in default.conf are still array variables after
# reading the user configuration, fixes common user config error: https://github.com/rear/rear/issues/2930

array_variables=($(
    sed -n -e '/^[A-Z_]\+=(/s/=.*//p' "$SHARE_DIR"/conf/default.conf
))


for config in "$CONFIG_DIR"/{site,local,rescue}.conf "${CONFIG_APPEND_FILES_PATHS[@]}"; do
    test -r "$config" || continue
    for var in "${array_variables[@]}"; do
        mapfile -t var_assignments < <(
            sed -n -E -e "/$var\+?=/p" "$config"
            )
        for line in "${var_assignments[@]}"; do
            [[ "$line" == *$var?(+)=\(* ]] || Error "Missing array assignment like +=(...) for $var in $config:$LF$line$LF"
        done
    done
done


unset array_variables