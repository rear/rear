#
# saving result files via DP

test ${#RESULT_FILES[@]} -gt 0 || Error "No files to copy (RESULT_FILES is empty)"

ProgressStart "Saving result files with DP"
#DP_RESULT_FILES=()

# if DP_RESULT_FILES_PATH is unset, then save the result files where they are
test -z "$DP_RESULT_FILES_PATH" && DP_RESULT_FILES_PATH="$VAR_DIR/rescue"

if ! test -d "$DP_RESULT_FILES_PATH" ; then
	 mkdir -v -p "$DP_RESULT_FILES_PATH" 1>&8
	 ProgressStopIfError $? "Could not create '$DP_RESULT_FILES_PATH'"
fi

cp -r "$VAR_DIR/recovery" "$DP_RESULT_FILES_PATH"
ProgressStopOrError $? "Could not save result files with dataprotector"
