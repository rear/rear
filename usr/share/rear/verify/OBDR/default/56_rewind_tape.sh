# Prepare the tape for restore

# rewind tape device
mt -f ${TAPE_DEVICE} rewind
ProgressStopIfError $? "Could not rewind tape device ${TAPE_DEVICE}"
ProgressStep

# The tar starts at the third marker (zeros, iso, tar)
mt -f ${TAPE_DEVICE} fsf 3
ProgressStopIfError $? "Could not forward tape device ${TAPE_DEVICE} to marker 3"
ProgressStep
