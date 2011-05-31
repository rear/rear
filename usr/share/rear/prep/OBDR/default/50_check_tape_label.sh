# Check the tape label and verify that this tape can be erased

# Turn compression off for reading tape label
mt -f $TAPE_DEVICE compression off
ProgressStopIfError $? "Could not disable compression on tape device '${TAPE_DEVICE}'"
ProgressStep

# Set correct blocksize for reading tape label
mt -f $TAPE_DEVICE setblk 512
ProgressStopIfError $? "Could not set block size on tape device '${TAPE_DEVICE}'"
ProgressStep

# Read exactly one block
TAPE_LABEL=$(dd if=$TAPE_DEVICE count=1)
ProgressStopIfError $? "Could not read label from tape device '${TAPE_DEVICE}'"
ProgressStep

# Match label
[[ "REAR-000" == "${TAPE_LABEL:0:8}" ]]
ProgressStopIfError $? "Tape ($TAPE_DEVICE) does not have the proper REAR-000 label. Use 'rear labeltape' to allow this tape to be used in OBDR mode."
ProgressStep
