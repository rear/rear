# Write the ISO image to the tape

[[ -r "$ISO_DIR/$ISO_PREFIX.iso" ]]
ProgressStopIfError $? "The ISO image $ISO_DIR/$ISO_PREFIX.iso was not found or could not be read."
ProgressStep

LogPrint "Writing ISO image to tape"
mt -f  "$TAPE_DEVICE" rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

dd if=$ISO_DIR/$ISO_PREFIX.iso of=$TAPE_DEVICE ${OBDR_BLOCKSIZE:+bs=$OBDR_BLOCKSIZE}
ProgressStopIfError $? "ISO image could not be written to tape device '$TAPE_DEVICE'"
ProgressStep

mt -f ${TAPE_DEVICE} eof
ProgressStopIfError $? "Could not write EOF to tape device '$TAPE_DEVICE'"
ProgressStep

mt -f ${TAPE_DEVICE} compression on
ProgressStopIfError $? "Could not enable compression on tape device '$TAPE_DEVICE'"
ProgressStep

# Disable compression (as tape drive does compression already)
Log "Disable compression for backup (BACKUP_PROG_COMPRESS_*)"
BACKUP_PROG_COMPRESS_OPTIONS=
BACKUP_PROG_COMPRESS_SUFFIX=
