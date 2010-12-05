# rewind tape drive

# TODO: This might take a long while, we should give the user more feedback about
# what is going on !

Log "Rewinding tape"
mt -f  "${TAPE_DEVICE}" rewind
ProgressStopIfError $? "Problem with rewinding tape device ${TAPE_DEVICE}"
ProgressStep
Log "Finished rewinding tape"
