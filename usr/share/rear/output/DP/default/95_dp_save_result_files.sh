#
# saving result files via DP

[ ${#RESULT_FILES[@]} -gt 0 ]
StopIfError "No files to copy (RESULT_FILES is empty)"

LogPrint "Saving result files with DP"
#DP_RESULT_FILES=()

# if DP_RESULT_FILES_PATH is unset, then save the result files where they are
test -z "$DP_RESULT_FILES_PATH" && DP_RESULT_FILES_PATH="$VAR_DIR/rescue"

if ! test -d "$DP_RESULT_FILES_PATH" ; then
	mkdir -p $v "$DP_RESULT_FILES_PATH" >&2
	StopIfError "Could not create '$DP_RESULT_FILES_PATH'"
fi

cp -r $v "$VAR_DIR/recovery" "$DP_RESULT_FILES_PATH" >&2
StopIfError "Could not save result files with dataprotector"
