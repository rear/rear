# 200_check_rsync_relative_option.sh
# See issue #871 for details

# check for the --relative option in BACKUP_RSYNC_OPTIONS array
# for the default values see the standard definition in conf/default.conf file

if ! grep -q relative <<< $(echo ${BACKUP_RSYNC_OPTIONS[@]}); then
    BACKUP_RSYNC_OPTIONS+=( --relative )
    Log "Added option '--relative' to the BACKUP_RSYNC_OPTIONS array during $WORKFLOW workflow"
fi
