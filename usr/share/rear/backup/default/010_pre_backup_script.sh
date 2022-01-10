if test "$PRE_BACKUP_SCRIPT" ; then
    Log "Running PRE_BACKUP_SCRIPT '${PRE_BACKUP_SCRIPT[@]}'"
    eval "${PRE_BACKUP_SCRIPT[@]}"
fi

for command in "${PRE_BACKUP_COMMANDS[@]}"; do
    Log "Running PRE_BACKUP_COMMANDS: '$command'"
    eval "$command"
done

# If we have POST_BACKUP_{SCRIPT,COMMANDS}, make sure they run even if the
# backup code aborts
if test "$POST_BACKUP_SCRIPT"; then
    AddExitTask "${POST_BACKUP_SCRIPT[@]}"
fi
for command in "${POST_BACKUP_COMMANDS[@]}"; do
    AddExitTask "$command"
done
