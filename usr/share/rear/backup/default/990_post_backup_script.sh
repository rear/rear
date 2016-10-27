if test "$POST_BACKUP_SCRIPT" ; then
    Log "Running POST_BACKUP_SCRIPT '${POST_BACKUP_SCRIPT[@]}'"
    RemoveExitTask "${POST_BACKUP_SCRIPT[@]}"
    eval "${POST_BACKUP_SCRIPT[@]}"
fi
