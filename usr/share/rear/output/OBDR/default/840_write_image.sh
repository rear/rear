# Write the ISO image to the tape

[[ -r "$ISO_DIR/$ISO_PREFIX.iso" ]]
StopIfError "The ISO image $ISO_DIR/$ISO_PREFIX.iso was not found or could not be read."

LogPrint "Writing ISO image to tape"

dd if=$ISO_DIR/$ISO_PREFIX.iso of=$TAPE_DEVICE ${OBDR_BLOCKSIZE:+bs=$OBDR_BLOCKSIZE}
StopIfError "ISO image could not be written to tape device '$TAPE_DEVICE'"

mt -f ${TAPE_DEVICE} eof
StopIfError "Could not write EOF to tape device '$TAPE_DEVICE'"

mt -f ${TAPE_DEVICE} compression on >&2
if [[ $? -ne 0 ]] ; then
    ### Try datcompression (for SLES10,11)
    mt -f ${TAPE_DEVICE} datcompression on >&2
fi
LogIfError "Could not enable compression on tape device '$TAPE_DEVICE'"

# Disable compression (as tape drive does compression already)
Log "Disable compression for backup (BACKUP_PROG_COMPRESS_*)"
BACKUP_PROG_COMPRESS_OPTIONS=()
BACKUP_PROG_COMPRESS_SUFFIX=""
