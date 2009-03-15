# Check tape drive
PROGS=( "${PROGS[@]}"
mt
)

test -z "${TAPE_DEVICE}" 
ProgressStopIfError "No tape device defined: ${TAPE_DEVICE}"
ProgressStep

mt -f  "${TAPE_DEVICE}" status | tee "$TMP_DIR/tape_status" 1>&2
ProgressStopIfError  $PIPESTATUS "Problem with reading tape device ${TAPE_DEVICE}"
ProgressStep

grep -q WR_PROT "$TMP_DIR/tape_status" && \
	ProgressStopIfError 1 "Tape is write protected in device ${TAPE_DEVICE}"
