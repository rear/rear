# Prepare the tape for restore

LogPrint "Rewinding tape"

mt -f  "$TAPE_DEVICE" rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

# The tar starts at the third marker (zeros, iso, tar)
mt -f ${TAPE_DEVICE} fsf 3
StopIfError "Could not forward tape device '$TAPE_DEVICE' to marker 3"
