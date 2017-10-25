
# restore files with TSM
# have to do this for each filespace

export animated_cursor_phase='0'
function animated_cursor () {
    case "$animated_cursor_phase" in
        (3)
            echo -en '|\r'
            animated_cursor_phase='0'
            ;;
        (2)
            echo -en '\\\r'
            animated_cursor_phase='3'
            ;;
        (1)
            echo -en '-\r'
            animated_cursor_phase='2'
            ;;
        (*)
            echo -en '/\r'
            animated_cursor_phase='1'
            ;;
    esac
}

for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    # make sure FileSpace has a trailing / (for dsmc)
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    LogPrint "Restoring ${filespace}"
    TsmProcessed=""
    Log "Running 'dsmc restore ${filespace}* $TARGET_FS_ROOT/$filespace -verbose -subdir=yes -replace=all -tapeprompt=no ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    # Use the original STDOUT when 'rear' was launched by the user for the 'while read ... echo' output
    # but keep STDERR of the 'while' command going to the log file so that 'rear -D' output goes to the log file:
    LC_ALL=${LANG_RECOVER} dsmc restore "${filespace}" "$TARGET_FS_ROOT/${filespace}/" \
        -verbose -subdir=yes -replace=all \
        -tapeprompt=no "${TSM_DSMC_RESTORE_OPTIONS[@]}" \
      | while read Line ; do
            if test "${Line:0:8}" == "ANS1898I" ; then
                TsmProcessed="$(echo "${Line:9}" | tr -s '*') "
                # Trigger animated_cursor:
                Line="Restoring"
            fi
            if test "${Line:0:9}" == "Restoring" ; then
                echo -n "$TsmProcessed"
                animated_cursor
            else
                echo "$Line"
            fi
        done 1>&7
done
