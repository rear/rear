
# Restore files with TSM.
# This is done for each filespace.
local num=0
local filespace=""
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    # Make sure FileSpace has a trailing / (for dsmc)
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    LogUserOutput "Restoring TSM filespace $filespace"
    Log "Running 'dsmc restore $filespace $TARGET_FS_ROOT/$filespace -verbose -subdir=yes -replace=all -tapeprompt=no ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    # Regarding usage of '0<&6 1>&7 2>&8' see "What to do with stdin, stdout, and stderr" in https://github.com/rear/rear/wiki/Coding-Style
    LC_ALL=${LANG_RECOVER} dsmc restore "$filespace" "$TARGET_FS_ROOT/$filespace/" -verbose -subdir=yes -replace=all -tapeprompt=no "${TSM_DSMC_RESTORE_OPTIONS[@]}" 0<&6 1>&7 2>&8
done

