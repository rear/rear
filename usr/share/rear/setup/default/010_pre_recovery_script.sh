
# The PRE_RECOVERY_COMMANDS are called directly before the PRE_RECOVERY_SCRIPT
# so PRE_RECOVERY_COMMANDS can also be used to prepare things for the PRE_RECOVERY_SCRIPT:

local command
for command in "${PRE_RECOVERY_COMMANDS[@]}" ; do
    Log "Running PRE_RECOVERY_COMMANDS '$command'"
    eval "$command"
done

if test "$PRE_RECOVERY_SCRIPT" ; then
    Log "Running PRE_RECOVERY_SCRIPT '${PRE_RECOVERY_SCRIPT[@]}'"
    eval "${PRE_RECOVERY_SCRIPT[@]}"
fi
