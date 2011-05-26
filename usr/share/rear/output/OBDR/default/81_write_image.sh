# Write the ISO image to the tape

[[ -r "$ISO_DIR/$ISO_PREFIX.iso" ]]
ProgressStopIfError $? "The ISO image $ISO_DIR/$ISO_PREFIX.iso was not found or could not be read."
ProgressStep

dd if=$ISO_DIR/$ISO_PREFIX.iso of=${TAPE_DEVICE} ${OBDR_BLOCKSIZE:+bs=$OBDR_BLOCKSIZE}
ProgressStopIfError $? "ISO image could not be written to ${TAPE_DEVICE}"
ProgressStep

mt -f ${TAPE_DEVICE} eof
ProgressStopIfError $? "Could not write EOF to ${TAPE_DEVICE}"
ProgressStep

mt -f ${TAPE_DEVICE} compression on
ProgressStopIfError $? "Could not enable compression on ${TAPE_DEVICE}"
ProgressStep
