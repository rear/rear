# write the OBDR header to tape
PROGS=( "${PROGS[@]}" dd )

LogPrint "Writing OBDR header to tape in drive '$TAPE_DEVICE'"

mt -f  "$TAPE_DEVICE" rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

mt -f "$TAPE_DEVICE" compression off
if [[ $? -ne 0 ]] ; then
    ### Try datcompression (for SLES10,11)
    mt -f "${TAPE_DEVICE}" datcompression off
fi
LogIfError "Could not disable compression on tape device '$TAPE_DEVICE'"

mt -f "$TAPE_DEVICE" setblk 512
StopIfError "Could not set block size on tape device '$TAPE_DEVICE'"

### Make sure we set a tape label and total padding of 20 blocks of size 512
printf 'REAR-000%10232s' ' ' | tr ' ' '\0' | dd of=$TAPE_DEVICE bs=512 count=20
StopIfError "OBDR header could not be written to tape device '$TAPE_DEVICE'"
