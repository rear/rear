if test "$PRE_RECOVERY_SCRIPT" ; then
    Log "Running PRE_RECOVERY_SCRIPT '${PRE_RECOVERY_SCRIPT[@]}'"
    eval "${PRE_RECOVERY_SCRIPT[@]}"
fi

for command in "${PRE_RECOVERY_COMMANDS[@]}"; do
    Log "Running PRE_RECOVERY_COMMANDS: '$command'"
    eval "$command"
done

# vim: set et ts=4 sw=4:
