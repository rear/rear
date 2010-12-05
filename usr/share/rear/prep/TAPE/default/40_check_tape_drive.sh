# Check tape drive
PROGS=( "${PROGS[@]}" mt )

# test for cciss driver and include the necessary tools
if grep -q '^cciss ' /proc/modules; then
	PROGS=( "${PROGS[@]}" "${PROGS_OBDR[@]}" )
fi

test "${TAPE_DEVICE}"
ProgressStopIfError $? "No tape device defined: ${TAPE_DEVICE}"
ProgressStep

mt -f "${TAPE_DEVICE}" status | tee "$TMP_DIR/tape_status" 1>&2
ProgressStopIfError $PIPESTATUS "Problem with reading tape device ${TAPE_DEVICE}"
ProgressStep

grep -q WR_PROT "$TMP_DIR/tape_status" && \
	ProgressStopIfError 1 "Tape is write protected in device ${TAPE_DEVICE}"
ProgressStep
