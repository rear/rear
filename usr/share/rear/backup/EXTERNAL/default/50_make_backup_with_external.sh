# run the external backup program
LogPrint "Running external backup command"
Log "Running '${EXTERNAL_BACKUP[@]}'"
eval "${EXTERNAL_BACKUP[@]}"
ret=$?
if IsInArray $ret "${EXTERNAL_IGNORE_ERRORS[@]}" ; then
	Log "WARNING: Ignoring external backup command exit code of '$ret'."
elif test $ret -gt 0 ; then
	Error "External backup command failed with $ret"
fi
LogPrint "Finished external backup command"
