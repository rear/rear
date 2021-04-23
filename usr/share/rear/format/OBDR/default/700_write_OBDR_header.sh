# write the OBDR header to tape

PROGS+=( dd )

LogPrint "Writing OBDR header to tape in drive '$TAPE_DEVICE'"

mt -f  "$TAPE_DEVICE" rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

mt -f "$TAPE_DEVICE" compression off >&2
if [[ $? -ne 0 ]] ; then
    ### Try datcompression (for SLES10,11)
    mt -f "${TAPE_DEVICE}" datcompression off >&2
fi
LogIfError "Could not disable compression on tape device '$TAPE_DEVICE'"

mt -f "$TAPE_DEVICE" setblk 512
StopIfError "Could not set block size on tape device '$TAPE_DEVICE'"

### Make sure we set a tape label and total padding of 20 blocks of size 512
# FIXME: Probably this only works with the default USB_DEVICE_FILESYSTEM_LABEL='REAR-000'
# but not with another value of different length (cf. https://github.com/rear/rear/issues/1535)
printf "$USB_DEVICE_FILESYSTEM_LABEL%10232s" ' ' | tr ' ' '\0' | dd of=$TAPE_DEVICE bs=512 count=20
StopIfError "OBDR header could not be written to tape device '$TAPE_DEVICE'"

### Make sure we jump to block 20 before writing (needed for DAT320)
### "mt seek" is not supported on all tape devices, do not stop on failure
mt -f "${TAPE_DEVICE}" seek 20
LogIfError "Could not seek to block 20 on tape device '$TAPE_DEVICE'"
