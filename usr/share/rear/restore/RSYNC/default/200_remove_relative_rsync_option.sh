# 200_remove_relative_rsync_option.sh
# See issue #871
# rsync restore was successfully tested by Vegas (see http://pikachu.3ti.be/pipermail/rear-users/2016-June/003350.html)
# without the --relative option ; my feeling says it is better to remove it from array BACKUP_RSYNC_OPTIONS
# If I'm wrong please let us know (use issue mentioned above to comment)

if grep -q -- "--relative" <<< "${BACKUP_RSYNC_OPTIONS[*]}" ; then
    BACKUP_RSYNC_OPTIONS=( $( RmInArray "--relative" "${BACKUP_RSYNC_OPTIONS[@]}" ) )
    Log "Removed option '--relative' from the BACKUP_RSYNC_OPTIONS array during $WORKFLOW workflow"
fi
if grep -q -- "-R" <<< "${BACKUP_RSYNC_OPTIONS[*]}" ; then
    BACKUP_RSYNC_OPTIONS=( $( RmInArray "-R" "${BACKUP_RSYNC_OPTIONS[@]}" ) )
    Log "Removed option '-R' from the BACKUP_RSYNC_OPTIONS array during $WORKFLOW workflow"
fi
