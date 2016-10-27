# set tape block size

Log "Set tape block size to ${OBDR_BLOCKSIZE:-0}"
mt -f  "${TAPE_DEVICE}" setblk ${OBDR_BLOCKSIZE:-0}
StopIfError "Problem with setting tape blocksize to ${OBDR_BLOCKSIZE:-0} on tape device '${TAPE_DEVICE}'"
