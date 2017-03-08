# set tape block size

Log "Set tape block size to ${TAPE_BLOCKSIZE:-0}"
mt -f  "${TAPE_DEVICE}" setblk ${TAPE_BLOCKSIZE:-0}
StopIfError "Problem with setting tape blocksize to ${TAPE_BLOCKSIZE:-0} on tape device '${TAPE_DEVICE}'"
