# Create the 'initial program' to boot/load the ReaR recovery system
# on IBM Z via IPL (initial program load)
LogPrint "Creating initial program for IPL on IBM Z"
RESULT_FILES+=( $KERNEL_FILE $TMP_DIR/$REAR_INITRD_FILENAME )

