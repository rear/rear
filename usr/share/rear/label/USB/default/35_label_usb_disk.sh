ProgressStep
USB_LABEL="$(e2label $REAL_USB_DEVICE)"
if [[ "$USB_LABEL" != "REAR-000" ]]; then
	ProgressStep
	e2label $REAL_USB_DEVICE REAR-000
	ProgressStopIfError $? "Could not label '$REAL_USB_DEVICE' with REAR-000"
	USB_LABEL="$(e2label $REAL_USB_DEVICE)"
fi
ProgressStep
Log "Device '$REAL_USB_DEVICE' has label $USB_LABEL"
