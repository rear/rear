# run the external restore program
LogPrint "Running external restore command"
Log "Running '${EXTERNAL_RESTORE[@]}'"
eval "${EXTERNAL_RESTORE[@]}" || Error "External restore command failed with $?"
LogPrint "Finished external restore command"
