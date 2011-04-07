# Prepare the tape for restore

# The tar starts at the third marker (zeros, iso, tar)
mt -f ${TAPE_DEVICE} fsf 3
ProgressStopIfError $? "Could not forward tape device ${TAPE_DEVICE} to marker 3"
ProgressStep
