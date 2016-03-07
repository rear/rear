# 40_check_backup_special_files.sh
# tell "rear checklayout" to watch over special backup related files
case $BACKUP in
    TSM         ) CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]}  /etc/adsm/TSM.PWD ) ;;
    FDRUPSTREAM ) CHECK_CONFIG_FILES=( "${CHECK_CONFIG_FILES[@]}" "${CHECK_CONFIG_FILES_FDRUPSTREAM[@]}" ) ;;
esac
