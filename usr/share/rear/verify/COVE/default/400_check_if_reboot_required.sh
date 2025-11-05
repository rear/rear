if [ -e "${TMP_DIR}/cove_rear_layout_code_done" ]; then
    text="A new recovery attempt has been detected. \
Some devices may have been mounted since the last attempt, \
which could prevent the recovery from completing. \
Please reboot the system and start the recovery again."
    cove_print_in_frame "WARNING" "$text"
fi
