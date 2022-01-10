if test "$POST_RECOVERY_SCRIPT" ; then
    Log "Running POST_RECOVERY_SCRIPT '${POST_RECOVERY_SCRIPT[@]}'"
    eval "${POST_RECOVERY_SCRIPT[@]}"
fi

for command in "${POST_RECOVERY_COMMANDS[@]}"; do
    Log "Running POST_RECOVERY_COMMANDS: '$command'"
    eval "$command"
done

# vim: set et ts=4 sw=4:
