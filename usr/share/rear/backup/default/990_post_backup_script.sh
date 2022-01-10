if test "$POST_BACKUP_SCRIPT" ; then
    Log "Running POST_BACKUP_SCRIPT '${POST_BACKUP_SCRIPT[@]}'"
    RemoveExitTask "${POST_BACKUP_SCRIPT[@]}"
    eval "${POST_BACKUP_SCRIPT[@]}"
fi

for command in "${POST_BACKUP_COMMANDS[@]}"; do
    Log "Running POST_BACKUP_COMMANDS: '$command'"
    RemoveExitTask "$command"
    eval "$command"
done

# vim: set et ts=4 sw=4:
