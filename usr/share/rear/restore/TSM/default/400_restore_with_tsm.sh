
# Restore files with TSM.
# This is done for each filespace.
local num=0
local filespace=""
local dsmc_restore_exit_code=0
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    # Make sure filespace has a trailing / (for dsmc):
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    LogUserOutput "Restoring TSM filespace $filespace"
    Log "Running 'LC_ALL=$LANG_RECOVER dsmc restore $filespace $TARGET_FS_ROOT/$filespace -subdir=yes -replace=all -tapeprompt=no ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    # Regarding usage of '0<&6 1>&7 2>&8' see "What to do with stdin, stdout, and stderr" in https://github.com/rear/rear/wiki/Coding-Style
    LC_ALL=$LANG_RECOVER dsmc restore "$filespace" "$TARGET_FS_ROOT/$filespace" -subdir=yes -replace=all -tapeprompt=no "${TSM_DSMC_RESTORE_OPTIONS[@]}" 0<&6 1>&7 2>&8
    dsmc_restore_exit_code=$?
    # When 'dsmc restore' results a non-zero exit code inform the user but do not abort the whole "rear recover" here
    # because it could be an unimportant reason why 'dsmc restore' finished with a non-zero exit code:
    test $dsmc_restore_exit_code -eq 0 || LogPrintError "Restoring TSM filespace $filespace may have failed ('dsmc restore' returns '$dsmc_restore_exit_code')"
done

