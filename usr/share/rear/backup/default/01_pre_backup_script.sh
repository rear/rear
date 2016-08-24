if test "$PRE_BACKUP_SCRIPT" ; then
    Log "Running PRE_BACKUP_SCRIPT '${PRE_BACKUP_SCRIPT[@]}'"
    AddExitTask "$(eval "${POST_BACKUP_SCRIPT[@]}")"
    eval "${PRE_BACKUP_SCRIPT[@]}"
fi
