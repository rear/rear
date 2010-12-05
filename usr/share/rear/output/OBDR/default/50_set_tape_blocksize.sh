# set tape block size

Log "Set tape block size to ${TAPE_BLOCKSIZE}"
mt -f  "${TAPE_DEVICE}" setblk ${TAPE_BLOCKSIZE}
ProgressStopIfError $? "Problem with setting tape blocksize to ${TAPE_BLOCKSIZE} on tape device ${TAPE_DEVICE}"
ProgressStep
