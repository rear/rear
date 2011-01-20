# rewind tape drive

# TODO: This might take a long while, we should give the user more feedback about
# what is going on !

SpinnerSleep 5		# for slower tape devices
Log "Rewinding tape"
mt -f  "${TAPE_DEVICE}" rewind 
ProgressStopIfError $? "Problem with rewinding tape device ${TAPE_DEVICE}"
Log "Finished rewinding tape"
ProgressStep
