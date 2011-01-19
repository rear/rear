# Write the ISO image to the tape

if [ ! -r "$ISO_DIR/$ISO_PREFIX.iso" ]; then
    Error "The ISO image $ISO_DIR/$ISO_PREFIX.iso was not found or could not be read."
fi

dd if=$ISO_DIR/$ISO_PREFIX.iso of=${TAPE_DEVICE} ${TAPE_BLOCKSIZE:+bs=$TAPE_BLOCKSIZE}
ProgressStopIfError $? "ISO image could not be written to ${TAPE_DEVICE}"
ProgressStep

mt -f ${TAPE_DEVICE} eof
ProgressStopIfError $? "Could not write EOF to ${TAPE_DEVICE}"
ProgressStep

mt -f ${TAPE_DEVICE} compression on
ProgressStopIfError $? "Could not enable compression on ${TAPE_DEVICE}"
ProgressStep
