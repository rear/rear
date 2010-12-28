# write the OBDR header to tape
PROGS=( "${PROGS[@]}"
dd
)
mt -f "${TAPE_DEVICE}" compression off
mt -f "${TAPE_DEVICE}" setblk 512
Log "Writing OBDR header to ${TAPE_DEVICE}"
dd if=/dev/zero of=${TAPE_DEVICE} bs=512 count=20
ProgressStopIfError $? "OBDR header could not be written to ${TAPE_DEVICE}"
ProgressStep
