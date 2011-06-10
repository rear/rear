# rewind tape drive

# TODO: This might take a long while, we should give the user more feedback about
# what is going on !

LogPrint "Rewinding tape"
mt -f "$TAPE_DEVICE" rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

Log "Finished rewinding tape"
