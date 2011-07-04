# run the external restore program
LogPrint "Running external restore command"
Log "Running '${EXTERNAL_RESTORE[@]}'"
eval "${EXTERNAL_RESTORE[@]}"
ret=$?
if IsInArray $ret "${EXTERNAL_IGNORE_ERRORS[@]}" ; then
	Log "WARNING: Ignoring external restore command exit code of '$ret'."
elif test $ret -gt 0 ; then
	Error "External restore command failed with $ret"
fi
LogPrint "Finished external restore command"
