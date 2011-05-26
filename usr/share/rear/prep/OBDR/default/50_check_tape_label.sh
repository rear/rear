# Check the tape label and verify that this tape can be erased

### Read exactly one block
TAPE_LABEL=$(dd if=$TAPE_DEVICE count=1)

[[ "REAR-000" == "${TAPE_LABEL:0:8}" ]]
ProgressStopIfError $? "Tape ($TAPE_DEVICE) does not have the proper REAR-000 label. Use 'rear labeltape' to allow this tape to be used in OBDR mode."
ProgressStep
