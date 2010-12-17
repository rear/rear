#
# saving result files via DP

test ${#RESULT_FILES[@]} -gt 0 || Error "No files to copy (RESULT_FILES is empty)"

ProgressStart "Saving result files with DP"
DP_RESULT_FILES=()

# decide where to put the result files for saving them with DP
# if DP_RESULT_FILE_PATH is unset, then save the result files where they are
# NOTE: Make sure that your DP installation will not silently skip files in /tmp !
test -z "$DP_RESULT_FILE_PATH" && DP_RESULT_FILE_PATH="$CONFIG_DIR/DP"

if ! test -d "$DP_RESULT_FILE_PATH" ; then
	 mkdir -v -p "$DP_RESULT_FILE_PATH" 1>&8
	 ProgressStopIfError $? "Could not create '$DP_RESULT_FILE_PATH'"
fi


cp -r "$VAR_DIR/recovery" "$DP_RESULT_FILE_PATH"

#if test "$DP_RESULT_FILE_PATH" != "/tmp" ; then
#	cp -v  "${RESULT_FILES[@]}" "$DP_RESULT_FILE_PATH" 1>&8
#	ProgressStopIfError $? "Could not copy result files to '$DP_RESULT_FILE_PATH'"
#	DP_RESULT_FILES=( 
#		$(
#			for fname in "${RESULT_FILES[@]}" ; do 
#				echo "$DP_RESULT_FILE_PATH/$(basename "$fname")"
#			done
#		 )
#	)
#else
#	DP_RESULT_FILES=( "${RESULT_FILES[@]}" )
#fi
#
#if test -s "$CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt" ; then
#	cp -v $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "$DP_RESULT_FILE_PATH/README" 1>&8
#	ProgressStopIfError $? "Could not copy '$CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt'"
#	DP_RESULT_FILES=( "${DP_RESULT_FILES[@]}" "$DP_RESULT_FILE_PATH"/README )
#fi

ret=0
ProgressStopOrError $ret "Could not save result files with dataprotector"
