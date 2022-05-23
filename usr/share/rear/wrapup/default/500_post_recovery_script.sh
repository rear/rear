
# The POST_RECOVERY_COMMANDS are called directly after the POST_RECOVERY_SCRIPT
# so POST_RECOVERY_COMMANDS can also be used to clean up things after the POST_RECOVERY_SCRIPT:

if test "$POST_RECOVERY_SCRIPT" ; then
    Log "Running POST_RECOVERY_SCRIPT '${POST_RECOVERY_SCRIPT[@]}'"
    eval "${POST_RECOVERY_SCRIPT[@]}"
fi

local command
for command in "${POST_RECOVERY_COMMANDS[@]}" ; do
    Log "Running POST_RECOVERY_COMMANDS '$command'"
    eval "$command"
done
