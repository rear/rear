# rewind tape drive

# TODO: This might take a long while, we should give the user more feedback about
# what is going on !

sleep 5
LogPrint "Rewinding tape"
mt -f  "${TAPE_DEVICE}" rewind 
ProgressStopIfError $? "Problem with rewinding tape device ${TAPE_DEVICE}"
Log "Finished rewinding tape"
ProgressStep
