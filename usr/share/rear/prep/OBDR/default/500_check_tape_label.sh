# Check the tape label and verify that this tape can be erased

LogPrint "Rewinding tape"

# Rewind tape drive to read out tape label
mt -f $TAPE_DEVICE rewind
StopIfError "Problem with rewinding tape in drive '$TAPE_DEVICE'"

# Turn compression off for reading tape label
mt -f $TAPE_DEVICE compression off >&2
if [[ $? -ne 0 ]] ; then
    ### Try datcompression (for SLES10,11)
    mt -f ${TAPE_DEVICE} datcompression off >&2
fi
LogIfError "Could not disable compression on tape device '$TAPE_DEVICE'"

# Set correct blocksize for reading tape label
mt -f $TAPE_DEVICE setblk 512
StopIfError "Could not set block size on tape device '$TAPE_DEVICE'"

# Read exactly one block
TAPE_LABEL=$(dd if=$TAPE_DEVICE count=1)
StopIfError "Could not read label from tape device '$TAPE_DEVICE'"

# Match label
# FIXME: Probably this only works with the default USB_DEVICE_FILESYSTEM_LABEL='REAR-000'
# but not with another value of different length (cf. https://github.com/rear/rear/issues/1535)
# see prep/OBDR/default/700_write_OBDR_header.sh
[[ "$USB_DEVICE_FILESYSTEM_LABEL" == "${TAPE_LABEL:0:8}" ]]
StopIfError "Tape ($TAPE_DEVICE) does not have the proper '$USB_DEVICE_FILESYSTEM_LABEL' label. Use 'rear format $TAPE_DEVICE' to allow this tape to be used in OBDR mode."

