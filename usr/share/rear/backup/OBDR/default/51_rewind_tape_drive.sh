# rewind tape drive

# TODO: This might take a long while, we should give the user more feedback about
# what is going on !

Log "Rewinding tape"
mt -f  "${TAPE_DEVICE}" rewind 
StopIfError "Problem with rewinding tape device '${TAPE_DEVICE}'"

Log "Finished rewinding tape"
