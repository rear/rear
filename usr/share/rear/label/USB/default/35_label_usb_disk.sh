USB_LABEL="$(e2label $REAL_USB_DEVICE)"
if [ -z "$USB_LABEL" ]; then
	e2label $REAL_USB_DEVICE REAR-0
	ProgressStopIfError $? "Could not label '$REAL_USB_DEVICE' with REAR-0"
	USB_LABEL="$(e2label $REAL_USB_DEVICE)"
fi
Log "Device '$REAL_USB_DEVICE' has label $USB_LABEL"
