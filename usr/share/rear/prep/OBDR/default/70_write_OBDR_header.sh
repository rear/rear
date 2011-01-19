# write the OBDR header to tape
PROGS=( "${PROGS[@]}" dd )

mt -f "${TAPE_DEVICE}" compression off
ProgressStopIfError $? "Could not disable compression on tape device ${TAPE_DEVICE}"
ProgressStep

mt -f "${TAPE_DEVICE}" setblk 512
ProgressStopIfError $? "Could not set block size on tape device ${TAPE_DEVICE}"
ProgressStep

### Make sure we set a tape label and total padding of 20 blocks of size 512
printf 'REAR-000%10232s' ' ' | tr ' ' '\0' | dd of=${TAPE_DEVICE} bs=512 count=20
ProgressStopIfError $? "OBDR header could not be written to tape device ${TAPE_DEVICE}"
ProgressStep
