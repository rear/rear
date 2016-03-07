# saving result files via TSM

[ ${#RESULT_FILES[@]} -gt 0 ]
StopIfError "No files to copy (RESULT_FILES is empty)"

LogPrint "Saving result files with TSM"
TSM_RESULT_FILES=()

# decide where to put the result files for saving them with TSM
# if TSM_RESULT_FILE_PATH is unset, then save the result files where they are
# NOTE: Make sure that your TSM installation will not silently skip files in $TMP_DIR !
test -z "$TSM_RESULT_FILE_PATH" && TSM_RESULT_FILE_PATH=$TMP_DIR

if ! test -d "$TSM_RESULT_FILE_PATH" ; then
    mkdir -p $v "$TSM_RESULT_FILE_PATH" >&2
    StopIfError "Could not create '$TSM_RESULT_FILE_PATH'"
fi


if test "$TSM_RESULT_FILE_PATH" != "$TMP_DIR" ; then
    cp $v  "${RESULT_FILES[@]}" "$TSM_RESULT_FILE_PATH" >&2
    StopIfError "Could not copy result files to '$TSM_RESULT_FILE_PATH'"
    TSM_RESULT_FILES=(
       $(
             for fname in "${RESULT_FILES[@]}" ; do
                 echo "$TSM_RESULT_FILE_PATH/$(basename "$fname")"
             done
       )
    )
else
    TSM_RESULT_FILES=( "${RESULT_FILES[@]}" )
fi

if test -s $(get_template "RESULT_usage_$OUTPUT.txt") ; then
    cp $v $(get_template "RESULT_usage_$OUTPUT.txt") "$TSM_RESULT_FILE_PATH/README" >&2
    StopIfError "Could not copy '$(get_template RESULT_usage_$OUTPUT.txt)'"
    TSM_RESULT_FILES=( "${TSM_RESULT_FILES[@]}" "$TSM_RESULT_FILE_PATH"/README )
fi

if [[ "$TSM_RESULT_SAVE" = "n" ]]; then
    Log "Result saving via TSM skipped"
    return
fi

Log "Saving files '${TSM_RESULT_FILES[@]}' with dsmc"
if [[ -z "$TSM_ARCHIVE_MGMT_CLASS" ]]; then
    LC_ALL=${LANG_RECOVER} dsmc incremental "${TSM_RESULT_FILES[@]}" >&8
else
    LC_ALL=${LANG_RECOVER} dsmc archive -archmc="$TSM_ARCHIVE_MGMT_CLASS" "${TSM_RESULT_FILES[@]}" >&8
fi
ret=$?
# Error code 8 can be ignored
[ "$ret" -eq 0 -o "$ret" -eq 8 ]
StopIfError "Could not save result files with dsmc"

