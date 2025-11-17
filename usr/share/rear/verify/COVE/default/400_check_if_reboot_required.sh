#
# Check if layout code execution was not started
#

if [ -e "${LAYOUT_CODE_STARTED}" ]; then
    text="A new recovery attempt has been detected. \
Some devices may have been mounted since the last attempt, \
which could prevent the recovery from completing. \
Please reboot the system and start the recovery again."
    cove_print_in_frame "WARNING" "$text"
fi
