# Check tape drive
REQUIRED_PROGS+=( mt )

# Test for cciss driver and include the necessary tools
if grep -q '^cciss ' /proc/modules; then
    PROGS+=( "${PROGS_OBDR[@]}" )
    REQUIRED_PROGS+=( "${REQUIRED_PROGS_OBDR[@]}" )
fi

# Is a tape device provided
[[ "$TAPE_DEVICE" ]]
StopIfError "No tape device (TAPE_DEVICE) defined."

# Write out tape status
mt -f "$TAPE_DEVICE" status &>"$TMP_DIR/tape_status"
StopIfError "Problem with reading tape device '$TAPE_DEVICE'."

# Log tape status
cat $TMP_DIR/tape_status >&2

# Check if tape is online
grep -qE '\bONLINE\b' "$TMP_DIR/tape_status"
StopIfError "Tape in device '$TAPE_DEVICE' is not online."

# Check if tape is not write protected
! grep -q WR_PROT "$TMP_DIR/tape_status"
StopIfError "Tape in device '$TAPE_DEVICE' is write protected."
