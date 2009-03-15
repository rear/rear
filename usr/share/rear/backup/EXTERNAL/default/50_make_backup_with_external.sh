# run the external backup program
LogPrint "Running external backup command"
Log "Running '${EXTERNAL_BACKUP[@]}'"
eval "${EXTERNAL_BACKUP[@]}" || Error "External backup command failed with $?"
LogPrint "Finished external backup command"
