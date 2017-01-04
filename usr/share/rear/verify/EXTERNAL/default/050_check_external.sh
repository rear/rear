# run the external backup check
if test "$PING" ; then
	Log "Running: '${EXTERNAL_CHECK[@]}'"
	eval "${EXTERNAL_CHECK[@]}"
	StopIfError "External command check failed with $?"
else
	Log "Skipping external command check (PING is disabled)"
fi
